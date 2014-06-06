(* © 2014 RunOrg *)

open Std

include EndpointCommon
module Dictionary = EndpointDictionary 

(* Authentication
   ============== *)

let run_checked req path ctx action = 

  Run.with_context ctx begin

    let! auth_error = 
      match req # as_ with None -> return None | Some pid -> 
	match req # token with 
	| None -> return (Some (!! "Token needed to act as %S." (PId.to_string pid)))
	| Some token -> let! ok = Token.can_be token pid in
			if ok then return None else
			  return (Some (!! "Token %S does not allow acting as %S." 
					   (Token.I.to_string token) (PId.to_string pid)))
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

(* Endpoint definition utilities 
   ============================= *)

module SEndpointUtils = functor(A:sig
  module Arg : Fmt.FMT
  val path : string 
end) -> struct

  (* The original path, but split into a list of segments. *)
  let path = split A.path
  
  (* Register the endpoint action. *)
  let register lens action = 
    Dictionary.add (lens action) path

  (* Argument parser. Parses the request according to the provided path and 
     formatter. 
     
     For example, a path of /user/0113ba65f32/name?token=BAADF00D&id=13 
     parsed with a path definition of /user/{id}/name would result in a JSON 
     object of { "id": "0113ba65f32", "token": "BAADF00D" }
     
     This object is then passed to the argument parser. *)
  let args_of_request = 
    let seg_bindings = List.filter_map identity 
      (List.mapi (fun i seg -> if seg.[0] = '{' && seg.[String.length seg - 1] = '}' then
	  Some (i, String.sub seg 1 (String.length seg - 2)) else None) path) in  
    fun req ->
      let path = Array.of_list (req # path) in
      let map = List.fold_left (fun map (i,n) -> Map.add n path.(i) map) (req # params) seg_bindings in
      let json = Json.Object (List.of_map (fun k v -> k, Json.String v) map) in
      try Ok (A.Arg.of_json json) 
      with Json.Error (path,reason) -> Bad [ "in", String.concat "" path ; "reason", reason ]       

  (* The path to be used when logging. *)
  let logPath = "/" ^ A.path

  let bad_request ?(more=[]) error = 
    Httpd.json 
      ~status:`BadRequest 
      (Json.Object (("error", Json.String error) :: ("path", Json.String logPath) :: 
		       (List.map (fun (a,b) -> a, Json.String b) more)))

  (* Parse the arguments from the URI and query string. *)
  let parse req callback = 
    match args_of_request req with 
    | Bad more -> let! () = LogReq.trace "API parsing failed" in
		  return (bad_request ~more "Could not parse parameters")
    | Ok args -> callback args 

  (* Parse the body *)
  let parse_body of_json req callback = 

    let json = match req # body with Some (`JSON json) -> Some json | _ -> None in

    let parsed = 
      match json with None -> Bad None | Some json ->
	try Ok (of_json json) with Json.Error (path, reason) -> 
	  Bad (Some [ "at", "body" ^ String.concat "" path ; "reason", reason ])
    in

    match parsed with 
    | Bad more -> let! () = LogReq.trace "API parsing failed" in
		  return (bad_request ?more "Could not parse body")

    | Ok body -> callback body 
    
end 

module EndpointUtils = functor(A:sig
  module Arg : Fmt.FMT
  val path : string 
end) -> struct
    
  include SEndpointUtils(struct
    module Arg = A.Arg
    let path = "db/{db}/" ^ A.path
  end)
      
  (* Parse the arguments and database from the query string and URI. *)
  let parse req callback = 
    let db = match req # path with _ :: db :: _ -> Some db | _ -> None in
    match db with 
    | None -> let! () = LogReq.trace "API parsing failed" in
	      return (bad_request "Could not parse parameters")
    | Some db -> parse req begin fun args -> 
	let! ctx = Db.ctx (Id.of_string db) in
	match ctx with 
	| None -> let! () = LogReq.trace "API database not found" in 
		  return (respond_error None logPath (`NotFound (!! "Database %s does not exist" db)))
	| Some ctx -> let! () = LogReq.trace "API database found" in
		      run_checked req logPath ctx (callback args)
    end

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

  include SEndpointUtils(A) 

    register Dictionary.get (fun req ->
      parse req (fun args -> 
	let! () = LogReq.trace "API starting ..." in
	let! out = A.response req args in 
	let! () = LogReq.trace "API finished !" in
	return (respond logPath A.Out.to_json out)))

end

module Get = functor(A:GET_ARG) -> struct

  include EndpointUtils(A)

    register Dictionary.get (fun req -> 
      parse req (fun args -> 
	let! () = LogReq.trace "API starting ..." in
	let! out = A.response req args in
	let! () = LogReq.trace "API finished !" in
	return (respond logPath A.Out.to_json out)))

end

module type RAW_GET_ARG = sig
  module Arg : Fmt.FMT
  val path : string
  val response : Httpd.request -> Arg.t -> (O.ctx, Httpd.response) Run.t
end

module RawGet = functor(A:RAW_GET_ARG) -> struct

  include EndpointUtils(A) 

    register Dictionary.get (fun req -> 
      parse req (fun args -> 
	let! () = LogReq.trace "API starting ..." in
	let! out = A.response req args in
	let! () = LogReq.trace "API finished !" in
	return out))

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

  include EndpointUtils(A) 

    register Dictionary.delete (fun req -> 
      parse req (fun args -> 
	let! () = LogReq.trace "API starting ..." in
	let! out = A.response req args in
	let! () = LogReq.trace "API finished !" in
	return (respond logPath A.Out.to_json out)))	       

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
  
module SPost = functor(A:POST_ARG) -> struct

  include SEndpointUtils(A)

    register Dictionary.post (fun req -> 
      parse req (fun args -> 
	parse_body A.Post.of_json req (fun post -> 
	  let! () = LogReq.trace "API starting ..." in
	  let! out = A.response req args post in
	  let! () = LogReq.trace "API finished !" in 
	  return (respond logPath A.Out.to_json out))))

end

module Post = functor(A:POST_ARG) -> struct

  include EndpointUtils(A)
    
    register Dictionary.post (fun req -> 
      parse req (fun args -> 
	parse_body A.Post.of_json req (fun post ->
	  let! () = LogReq.trace "API starting ..." in
	  let! out = A.response req args post in
	  let! () = LogReq.trace "API finished !" in
	  return (respond logPath A.Out.to_json out))))

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

  include SEndpointUtils(A) 

    register Dictionary.put (fun req -> 
      parse req (fun args -> 
	parse_body A.Put.of_json req (fun put -> 
	  let! () = LogReq.trace "API starting ..." in
	  let! out = A.response req args put in 
	  let! () = LogReq.trace "API finished !" in
	  return (respond logPath A.Out.to_json out))))

end

module Put = functor(A:PUT_ARG) -> struct

  include EndpointUtils(A) 
  
    register Dictionary.put (fun req ->
      parse req (fun args -> 
	parse_body A.Put.of_json req (fun put -> 
	  let! () = LogReq.trace "API starting ..." in
	  let! out = A.response req args put in
	  let! () = LogReq.trace "API finished !" in
	  return (respond logPath A.Out.to_json out))))

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
    
  Dictionary.add (Dictionary.get action) (split path) 

let json path json = 

  let json = Json.serialize json in 
  let hash = String.base62_encode (Sha1.hash_of_string json) in 
  let etag = !! "%S" hash in

  let response = Httpd.raw ~headers:[
    "Content-Type", "application/json" ;
    "ETag", etag
  ] json in
      
  let action req = return response in

  Dictionary.add (Dictionary.get action) (split path) 

(* Dispatching requests
   ==================== *)
  
let dispatch req = 
  Dictionary.dispatch req
