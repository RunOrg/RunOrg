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
    try Ok (F.of_json json) 
    with Json.Error (path,reason) -> Bad [ "in", String.concat "" path ; "reason", reason ]       

let without_wildcards path_segs = 
  List.map (fun seg -> if seg.[0] = '{' then None else Some seg) path_segs
  
(* General response types
   ====================== *)

type error =   
  [ `Forbidden of string 
  | `BadRequest of string
  | `Unauthorized of string
  | `NotFound of string 
  | `Conflict of string
  ]

type 'a read_response = 
  [ `OK of 'a 
  | error
  | `WithJSON of Json.t * error ]

type 'a write_response = 
  [ 'a read_response | `Accepted of 'a ]

let error_body more path error = 
  let list = [ "error", Json.String error ; "path", Json.String path ] in
  let list = match more with None -> list | Some json -> ( "details", json ) :: list in
  Json.Object list 

let not_found more path error = 
  Httpd.json ~status:`NotFound (error_body more error path)

let forbidden more path error = 
  Httpd.json ~status:`Forbidden (error_body more error path)

let unauthorized more path error = 
  Httpd.json ~status:`Unauthorized (error_body more error path)

let bad_request more path error = 
  Httpd.json ~status:`BadRequest (error_body more error path)

let conflict more path error = 
  Httpd.json ~status:`Conflict (error_body more error path)

let method_not_allowed path allowed = 
  Httpd.json ~headers:[ "Allowed", String.concat ", " allowed] ~status:`MethodNotAllowed
    (error_body None "Method not allowed" path)

let bad_request ?(more=[]) path error = 
  Httpd.json ~status:`BadRequest 
    (Json.Object (("error", Json.String error) :: ("path", Json.String path) :: 
      (List.map (fun (a,b) -> a, Json.String b) more)))

let respond more path to_json = function
  | `Forbidden error -> forbidden (Some more) path error
  | `NotFound error -> not_found (Some more) path error
  | `Unauthorized error -> unauthorized (Some more) path error
  | `BadRequest error -> bad_request path error
  | `Conflict error -> conflict (Some more) path error

let respond path to_json = function
  | `Forbidden error -> forbidden None path error
  | `NotFound error -> not_found None path error
  | `Unauthorized error -> unauthorized None path error
  | `BadRequest error -> bad_request path error
  | `Conflict error -> conflict None path error
  | `WithJSON (more,what) -> respond more path to_json what 
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
      | [] -> let! () = LogReq.trace "API dispatch failed" in
	      return (not_found None ("/" ^ String.concat "/" (req # path)) "No such resource") 
      | [r] -> begin match lens r with 
	| None -> let! () = LogReq.trace "API dispatch failed" in
		  return (method_not_allowed (r.path) (allow r))
	| Some action -> let! () = LogReq.trace "API dispatched" in
			 action req 
      end
      | (h :: _) as list -> 
	match List.find_map lens list with 
	| Some f -> let! () = LogReq.trace "API dispatched" in
		    f req 
	| None   -> let! () = LogReq.trace "API dispatch failed" in
		    return (method_not_allowed (h.path) (allow h))
	  
end

(* Authentication
   ============== *)

let run_checked req path ctx action = 

  Run.with_context ctx begin

    let! auth_error = 
      match req # as_ with None -> return None | Some cid -> 
	match req # token with 
	| None -> return (Some (!! "Token needed to act as %S." (CId.to_string cid)))
	| Some token -> let! ok = Token.can_be token cid in
			if ok then return None else
			  return (Some (!! "Token %S does not allow acting as %S." 
					   (Token.I.to_string token) (CId.to_string cid)))
    in
    
    match auth_error with
    | None -> let! () = if req # as_ = None then return () else LogReq.trace "API token verified" in
	      action
    | Some msg -> let! () = LogReq.trace "API token invalid" in
		  return (Httpd.json ~status:`Unauthorized (Json.Object [
		    "error", Json.String msg ;
		    "path",  Json.String path ;
		  ]))

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

    match argparse req with 
    | Bad more -> let! () = LogReq.trace "API parsing failed" in
		  return (bad_request ~more logPath "Could not parse parameters") 
    | Ok args -> let! () = LogReq.trace "API starting ..." in
		 let! out = A.response req args in 
		 let! () = LogReq.trace "API finished !" in
		 return (respond logPath A.Out.to_json out)

  let () = Dictionary.add (snd Dictionary.get action) path

end

module Get = functor(A:GET_ARG) -> struct

  let path = split ("db/{-}/" ^ A.path) 
  let argparse = argparse (module A.Arg : Fmt.FMT with type t = A.Arg.t) path

  let logPath = "/db/{db}/" ^ A.path
    
  let action req = 
    let db = match req # path with _ :: db :: _ -> Some db | _ -> None in
    match db with 
    | None -> let! () = LogReq.trace "API parsing failed" in 
	      return (bad_request logPath "Could not parse parameters") 
    | Some db ->
      match argparse req with 
      | Bad more -> let! () = LogReq.trace "API parsing failed" in
		    return (bad_request ~more logPath "Could not parse parameters") 
      | Ok args ->
	let! ctx = Db.ctx (Id.of_string db) in
	match ctx with 
	| None -> let! () = LogReq.trace "API database not found" in 
		  return (not_found None logPath (!! "Database %s does not exist" db)) 
	| Some ctx -> let! () = LogReq.trace "API database found" in
		      run_checked req logPath ctx begin
			let! () = LogReq.trace "API starting ..." in
			let! out = A.response req args in
			let! () = LogReq.trace "API finished !" in
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
    match db with 
    | None -> let! () = LogReq.trace "API parsing failed" in
	      return (bad_request logPath "Could not parse parameters") 
    | Some db ->
      match argparse req with 
      | Bad more -> let! () = LogReq.trace "API parsing failed" in
		    return (bad_request ~more logPath "Could not parse parameters") 
      | Ok args ->
	let! ctx = Db.ctx (Id.of_string db) in
	match ctx with 
	| None -> let! () = LogReq.trace "API database missing" in 
		  return (not_found None logPath (!! "Database %s does not exist" db)) 
	| Some ctx -> let! () = LogReq.trace "API database found" in
		      run_checked req logPath ctx begin
			let! () = LogReq.trace "API starting ..." in
			let! out = A.response req args in
			let! () = LogReq.trace "API finished !" in
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

let parse_body of_json req = 
  match post_json req with None -> Bad None | Some json ->
    try Ok (of_json json) with Json.Error (path, reason) -> 
      Bad (Some [ "at", "body" ^ String.concat "" path ; "reason", reason ])

module SPost = functor(A:POST_ARG) -> struct

  let path = split A.path
  let argparse = argparse (module A.Arg : Fmt.FMT with type t = A.Arg.t) path

  let logPath = "/" ^ A.path

  let action req =    
    match argparse req with 
    | Bad more -> let! () = LogReq.trace "API parsing failed" in 
		  return (bad_request ~more logPath "Could not parse parameters") 
    | Ok args ->
      match parse_body A.Post.of_json req with 
      | Bad more -> let! () = LogReq.trace "API parsing failed" in 
		    return (bad_request ?more logPath "Could not parse body") 
      | Ok post -> let! () = LogReq.trace "API starting ..." in
		   let! out = A.response req args post in
		   let! () = LogReq.trace "API finished !" in 
		   return (respond logPath A.Out.to_json out)

  let () = Dictionary.add (snd Dictionary.post action) path

end

module Post = functor(A:POST_ARG) -> struct

  let path = split ("db/{-}/" ^ A.path) 
  let argparse = argparse (module A.Arg : Fmt.FMT with type t = A.Arg.t) path

  let logPath = "/db/{db}/" ^ A.path
    
  let action req = 
    let db = match req # path with _ :: db :: _ -> Some db | _ -> None in
    match db with 
    | None -> let! () = LogReq.trace "API parsing failed" in
	      return (bad_request logPath "Could not parse parameters") 
    | Some db ->
      match argparse req with 
      | Bad more -> let! () = LogReq.trace "API parsing failed" in 
		    return (bad_request ~more logPath "Could not parse parameters") 
      | Ok args -> 
	match parse_body A.Post.of_json req with 
	| Bad more -> let! () = LogReq.trace "API parsing failed" in 
		      return (bad_request ?more logPath "Could not parse body") 
	| Ok post ->
	  let! ctx = Db.ctx (Id.of_string db) in
	  match ctx with 
	  | None -> let! () = LogReq.trace "API database not found" in 
		    return (not_found None logPath (!! "Database %s does not exist" db)) 
	  | Some ctx -> let! () = LogReq.trace "API database found" in
			run_checked req logPath ctx begin
			  let! () = LogReq.trace "API starting ..." in
			  let! out = A.response req args post in
			  let! () = LogReq.trace "API finished !" in
			  return (respond logPath A.Out.to_json out)
			end

  let () = Dictionary.add (snd Dictionary.post action) path

end

(* PUT JSON endpoints
   ================== *)

module type PUT_ARG = sig
  module Arg : Fmt.FMT
  module Put : Fmt.FMT
  module Out : Fmt.FMT
  val path : string
  val response : Httpd.request ->  Arg.t -> Put.t -> (O.ctx, Out.t write_response) Run.t
end
  
module SPut = functor(A:PUT_ARG) -> struct

  let path = split A.path
  let argparse = argparse (module A.Arg : Fmt.FMT with type t = A.Arg.t) path

  let logPath = "/" ^ A.path

  let action req =    
    match argparse req with 
    | Bad more -> let! () = LogReq.trace "API parsing failed" in
		  return (bad_request ~more logPath "Could not parse parameters") 
    | Ok args ->
      match parse_body A.Put.of_json req with 
      | Bad more -> let! () = LogReq.trace "API parsing failed" in
		    return (bad_request ?more logPath "Could not parse body") 
      | Ok post -> let! () = LogReq.trace "API starting ..." in
		   let! out = A.response req args post in 
		   let! () = LogReq.trace "API finished !" in
		   return (respond logPath A.Out.to_json out)

  let () = Dictionary.add (snd Dictionary.put action) path

end

module Put = functor(A:PUT_ARG) -> struct

  let path = split ("db/{-}/" ^ A.path) 
  let argparse = argparse (module A.Arg : Fmt.FMT with type t = A.Arg.t) path

  let logPath = "/db/{db}/" ^ A.path
    
  let action req = 
    let db = match req # path with _ :: db :: _ -> Some db | _ -> None in
    match db with 
    | None -> let! () = LogReq.trace "API parsing failed" in 
	      return (bad_request logPath "Could not parse parameters") 
    | Some db -> 
      match argparse req with 
      | Bad more -> let! () = LogReq.trace "API parsing failed" in
		    return (bad_request ~more logPath "Could not parse parameters") 
      | Ok args -> 
	match parse_body A.Put.of_json req with 
	| Bad more -> let! () = LogReq.trace "API parsing failed" in
		      return (bad_request ?more logPath "Could not parse body") 
	| Ok post ->
	  let! ctx = Db.ctx (Id.of_string db) in
	  match ctx with 
	  | None -> let! () = LogReq.trace "API database not found" in 
		    return (not_found None logPath (!! "Database %s does not exist" db)) 
	  | Some ctx ->let! () = LogReq.trace "API database found" in
		       run_checked req logPath ctx begin
			 let! () = LogReq.trace "API starting ..." in
			 let! out = A.response req args post in
			 let! () = LogReq.trace "API finished !" in
			 return (respond logPath A.Out.to_json out)
		       end

  let () = Dictionary.add (snd Dictionary.put action) path

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

  let response = Httpd.raw ~headers:[
    "Content-Type", mime ;
    "ETag", !! "%S" hash ;      
  ] content in
    
  let action req = return response in 
    
  Dictionary.add (snd Dictionary.get action) (split path) 

let json path json = 

  let json = Json.serialize json in 
  let hash = String.base62_encode (Sha1.hash_of_string json) in 
  let etag = !! "%S" hash in

  let response = Httpd.raw ~headers:[
    "Content-Type", "application/json" ;
    "ETag", etag
  ] json in
      
  let action req = return response in

  Dictionary.add (snd Dictionary.get action) (split path) 

(* Dispatching requests
   ==================== *)
  
let dispatch req = 
  Dictionary.dispatch req
