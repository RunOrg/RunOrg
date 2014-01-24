(* © 2014 RunOrg *)

open Std

(* Canonical splitting: all non-empty segments. *)
let split path = 
  List.filter (fun s -> s <> "") (String.nsplit path "/") 

(* Argument parser. Parses the request according to the provided path and 
   formatter. 

   For example, a path of /user/0113ba65f32/name?token=BAADF00D&id=13 
   parsed with a path definition of /user/{id}/name would result in a JSON 
   object of { "id": "0113ba65f32", "token": "BAADF00D" }

   This object is then passed to the argument parser. *)
let argparse (type t) (a : (module Fmt.FMT with type t = t)) path_segs = 
  let module F = (val a : Fmt.FMT with type t = t) in
  let seg_bindings = List.filter_map identity 
    (List.mapi (fun i seg -> if seg.[0] = '{' && seg.[String.length seg - 1] = '}' then
	Some (i, String.sub seg 1 (String.length seg - 2)) else None) path_segs) in  
  fun req ->
    let path = Array.of_list (req # path) in
    let map = List.fold_left (fun map (i,n) -> Map.add n path.(i) map) (req # params) seg_bindings in
    let json = Json.Object (List.of_map (fun k v -> k, Json.String v) map) in
    F.of_json_safe json 
      
let without_wildcards path_segs = 
  List.map (fun seg -> if seg.[0] = '{' then None else Some seg) path_segs
  
(* General response types
   ====================== *)

type 'a read_response = 
  [ `OK of 'a 
  | `Forbidden of string 
  | `Unauthorized of string
  | `BadRequest of string
  | `NotFound of string ]

type 'a write_response = 
  [ 'a read_response | `Accepted of 'a ]

let not_found path error = 
  Httpd.json ~status:`NotFound (Json.Object [ "error", Json.String error ; "path", Json.String path ])

let forbidden path error = 
  Httpd.json ~status:`Forbidden (Json.Object [ "error", Json.String error ; "path", Json.String path ])

let unauthorized path error = 
  Httpd.json ~status:`Unauthorized (Json.Object [ "error", Json.String error ; "path", Json.String path ])

let bad_request path error = 
  Httpd.json ~status:`BadRequest (Json.Object [ "error", Json.String error ; "path", Json.String path ])

let method_not_allowed path allowed = 
  Httpd.json ~headers:[ "Allowed", String.concat ", " allowed] ~status:`MethodNotAllowed
    (Json.Object [ "error", Json.String "Method not allowed" ; "path", Json.String path ])

let bad_request path error = 
  Httpd.json ~status:`BadRequest (Json.Object [ "error", Json.String error ; "path", Json.String path ])

let respond path to_json = function
  | `Forbidden error -> forbidden path error
  | `NotFound error -> not_found path error
  | `Unauthorized error -> unauthorized path error
  | `BadRequest error -> bad_request path error
  | `OK out -> Httpd.json (to_json out)
  | `Accepted out -> Httpd.json ~status:`Accepted (to_json out)

(* Storage for all endpoints
   ========================= *)

(* We're keeping all endpoints together in order to send a 405 Method Not Allowed. *)

module Dictionary = struct

  type action = Httpd.request -> (O.ctx, Httpd.response) Run.t
  type resource = { 
    get : action option ; 
    post : action option ; 
    put : action option ; 
    delete : action option ;
    path : string ; 
  }

  let empty_resource path = { get = None ; post = None ; put = None ; delete = None ; path }

  (* Lenses for accessing actions. [fst] reads, [snd] writes. *)

  let get = (fun r -> r.get), (fun x r -> { r with get = Some x })
  let post = (fun r -> r.post), (fun x r -> { r with post = Some x })
  let put = (fun r -> r.put), (fun x r -> { r with put = Some x })
  let delete = (fun r -> r.delete), (fun x r -> { r with delete = Some x })

  (* Used for the "Allow:" header on a 405 Method Not Allowed response. *)
  let allow r = 
    let a = if r.get <> None then [ "GET" ] else [] in
    let a = if r.post <> None then "POST" :: a else a in
    let a = if r.put <> None then "PUT" :: a else a in 
    if r.delete <> None then "DELETE" :: a else a 

  (* The dictionary itself is a series of nested hash tables. The first level is in fact
     an array, with the number of segments in the path acting as a separator.
     
     Then, each level of the subtree applies a match to the corresponding segment
     in the path. *)
      
  let maximum_path_size = 16 (* segments *) 

  type tree = 
    | Choice of (string option, tree) Map.t
    | Resource of resource

  let empty = Choice Map.empty 

  let dictionary = Array.make maximum_path_size empty 
  let () = dictionary.(0) <- Resource (empty_resource "/")

  let add set spath = 
    let path = without_wildcards spath in 
    let rec insert current = function 
      | [] -> begin match current with 
	| None -> Resource (set (empty_resource ("/" ^ String.concat "/" spath)))
	| Some (Resource r) -> Resource (set r)
	| Some (Choice _) -> assert false (* The depth should always be correct *)
      end
      | seg :: t -> begin 
	let map = match current with None -> Map.empty | Some (Choice m) -> m | Some _ -> assert false in 
	let current = try Some (Map.find seg map) with Not_found -> None in 
	Choice (Map.add seg (insert current t) map)
      end  
    in
    let n = List.length path in 
    assert (n >= 0 && n < maximum_path_size) ;
    dictionary.(n) <- insert (Some dictionary.(n)) path 

  (* Querying the dictionary must take into account wildcards (represented
     by [None] segments. Returns all resources that match. *)
  let find segs = 
    let rec find acc current = function 
      | [] -> begin match current with 
	| Resource r -> r :: acc
	| Choice _ -> assert false (* The depth should always be correct *)
      end 
      | seg :: t -> begin 
	let map = match current with Choice m -> m | Resource _ -> assert false in 
	let acc = try find acc (Map.find None map) t with Not_found -> acc in
	try find acc (Map.find (Some seg) map) t with Not_found -> acc 
      end 
    in
    let n = List.length segs in     
    if n >= maximum_path_size then [] else find [] dictionary.(n) segs

  (* Dispatches a request, returns a response. *)
  let dispatch req = 

    let lens = fst (match req # verb with 
      | `GET -> get
      | `POST -> post
      | `PUT -> put
      | `DELETE -> delete) in

    match find (req # path) with 
      | [] -> return (not_found ("/" ^ String.concat "/" (req # path)) "No such resource") 
      | [r] -> begin match lens r with 
	| None -> return (method_not_allowed (r.path) (allow r))
	| Some action -> action req 
      end
      | (h :: _) as list -> 
	try List.find_map lens list req 
	with Not_found -> return (method_not_allowed (h.path) (allow h))

end

(* GET endpoints
   ============= *)

module type GET_ARG = sig
  module Arg : Fmt.FMT
  module Out : Fmt.FMT
  val path : string
  val response : Httpd.request -> Arg.t -> (O.ctx, Out.t read_response) Run.t
end

module SGet = functor(A:GET_ARG) -> struct

  let path = split A.path
  let argparse = argparse (module A.Arg : Fmt.FMT with type t = A.Arg.t) path

  let logPath = "/" ^ A.path 

  let action req =

    match argparse req with None -> return (bad_request logPath "Could not parse parameters") | Some args ->
      let! out = A.response req args in 
      return (respond logPath A.Out.to_json out)

  let () = Dictionary.add (snd Dictionary.get action) path

end

module Get = functor(A:GET_ARG) -> struct

  let path = split ("db/{-}/" ^ A.path) 
  let argparse = argparse (module A.Arg : Fmt.FMT with type t = A.Arg.t) path

  let logPath = "/db/{db}/" ^ A.path
    
  let action req = 
    let db = match req # path with _ :: db :: _ -> Some db | _ -> None in
    match db with None -> return (bad_request logPath "Could not parse parameters") | Some db ->
      match argparse req with None -> return (bad_request logPath "Could not parse parameters") | Some args ->
	let! ctx = Db.ctx (Id.of_string db) in
	match ctx with None -> return (not_found logPath (!! "Database %s does not exist" db)) | Some ctx ->
	  Run.with_context ctx begin
	    let! out = A.response req args in
	    return (respond logPath A.Out.to_json out)
	  end

  let () = Dictionary.add (snd Dictionary.get action) path

end

(* DELETE endpoints 
   ================ *)

module type DELETE_ARG = sig
  module Arg : Fmt.FMT
  module Out : Fmt.FMT
  val path : string
  val response : Httpd.request -> Arg.t -> (O.ctx, Out.t write_response) Run.t
end

module Delete = functor(A:DELETE_ARG) -> struct

  let path = split ("db/{-}/" ^ A.path) 
  let argparse = argparse (module A.Arg : Fmt.FMT with type t = A.Arg.t) path
    
  let logPath = "/db/{db}/" ^ A.path 

  let action req = 
    let db = match req # path with _ :: db :: _ -> Some db | _ -> None in
    match db with None -> return (bad_request logPath "Could not parse parameters") | Some db ->
      match argparse req with None -> return (bad_request logPath "Could not parse parameters") | Some args ->
	let! ctx = Db.ctx (Id.of_string db) in
	match ctx with None -> return (not_found logPath (!! "Database %s does not exist" db)) | Some ctx ->
	  Run.with_context ctx begin
	    let! out = A.response req args in
	    return (respond logPath A.Out.to_json out)
	  end

  let () = Dictionary.add (snd Dictionary.delete action) path

end

(* POST JSON endpoints
   =================== *)

module type POST_ARG = sig
  module Arg  : Fmt.FMT
  module Post : Fmt.FMT
  module Out  : Fmt.FMT
  val path : string
  val response : Httpd.request -> Arg.t -> Post.t -> (O.ctx, Out.t write_response) Run.t
end
  
let post_json req =
  match req # body with Some (`JSON json) -> Some json | _ -> None

module SPost = functor(A:POST_ARG) -> struct

  let path = split A.path
  let argparse = argparse (module A.Arg : Fmt.FMT with type t = A.Arg.t) path

  let logPath = "/" ^ A.path

  let action req =    
    match argparse req with None -> return (bad_request logPath "Could not parse parameters") | Some args ->
      match Option.bind (post_json req) A.Post.of_json_safe with 
      | None -> return (bad_request logPath "Could not parse body") 
      | Some post -> let! out = A.response req args post in 
		     return (respond logPath A.Out.to_json out)

  let () = Dictionary.add (snd Dictionary.post action) path

end

module Post = functor(A:POST_ARG) -> struct

  let path = split ("db/{-}/" ^ A.path) 
  let argparse = argparse (module A.Arg : Fmt.FMT with type t = A.Arg.t) path

  let logPath = "/db/{db}/" ^ A.path
    
  let action req = 
    let db = match req # path with _ :: db :: _ -> Some db | _ -> None in
    match db with None -> return (bad_request logPath "Could not parse parameters") | Some db ->
      match argparse req with None -> return (bad_request logPath "Could not parse parameters") | Some args -> 
	match Option.bind (post_json req) A.Post.of_json_safe with 
	| None -> return (bad_request logPath "Could not parse body") 
	| Some post ->
	  let! ctx = Db.ctx (Id.of_string db) in
	  match ctx with None -> return (not_found logPath (!! "Database %s does not exist" db)) | Some ctx ->
	    Run.with_context ctx begin
	      let! out = A.response req args post in
	      return (respond logPath A.Out.to_json out)
	    end

  let () = Dictionary.add (snd Dictionary.post action) path

end

(* Static content 
   ============== *)
let static path mime file =

  let content =
    let open Pervasives in 
    let channel = open_in file in 
    let length  = in_channel_length channel in
    if length > 0 then
      let buffer  = String.create length in 
      ( really_input channel buffer 0 length ;
	close_in channel ;
	buffer ) 
    else
      ( close_in channel ; 
	"" )
  in
  
  let hash = String.base62_encode (Sha1.hash_of_string content) in

  let action req = 
    return (Httpd.raw ~headers:[
      "Content-Type", mime ;
      "ETag", !! "%S" hash ;      
    ] content)
  in
    
  Dictionary.add (snd Dictionary.get action) (split path) 
  
let dispatch req = 
  Dictionary.dispatch req
