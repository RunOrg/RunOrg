(* © 2014 RunOrg *)

open Std
open EndpointCommon

(* We're keeping all endpoints together in order to send a 405 Method Not Allowed. *)

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
  
let without_wildcards path_segs = 
  List.map (fun seg -> if seg.[0] = '{' then None else Some seg) path_segs
    
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
    
(* The HTTP response sent when the requested method is not allowed. *)
let method_not_allowed path allowed = 
  Httpd.json 
    ~headers:[ "Allowed", String.concat ", " allowed] 
    ~status:`MethodNotAllowed
    (Json.Object [ 
      "error", Json.String "Method not allowed" ;
      "path",  Json.String path ])

(* The HTTP response sent when the URI does not match an endpoint. *)
let not_found path = 
  respond_error None path (`NotFound "No such resource")

(* Dispatches a request, returns a response. *)
let dispatch req = 
  
  let lens = match req # verb with 
    | `GET     -> Some (fst get)
    | `POST    -> Some (fst post)
    | `PUT     -> Some (fst put)
    | `DELETE  -> Some (fst delete)
    | `OPTIONS -> None in

  match lens with 

    (* Lens missing: OPTIONS *)
    | None -> return (Httpd.raw "")
      
      (* Lens available : GET, PUT, POST or DELETE. *)
    | Some lens -> 
      match find (req # path) with 
        | [] -> let! () = LogReq.trace "API dispatch failed" in
		return (not_found ("/" ^ String.concat "/" (req # path)))
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
			

(* Public interface
   ================ *)

type verb = resource -> resource 
let get action = snd get action
let put action = snd put action
let post action = snd post action
let delete action = snd delete action 
