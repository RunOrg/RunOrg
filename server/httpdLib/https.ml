(* © 2013 RunOrg *)

open Std
open Common

let init () =
  Ssl.init () 

let context socket config = 
  let ctx = Ssl.create_context Ssl.SSLv23 Ssl.Server_context in
  if config.key_password <> "" then Ssl.set_password_callback ctx (fun _ -> config.key_password) ;
  Ssl.use_certificate ctx config.certificate_path config.key_path ;
  ignore (Ssl.embed_socket socket ctx) ;
  ctx 

let parse context socket config handler = 
  try
    let ssl_socket = Ssl.embed_socket socket context in
    Ssl.accept ssl_socket ;   
    try 
      let request = Request.parse config ssl_socket in
      Log.trace "Request for: /%s" (String.concat "/" (request # path)) ;
      let () = Response.json ssl_socket `OK [] 
	(Json.Object [ "ok", Json.Bool true ]) in
      return ()
    with 
    | Request.HeaderTooLong -> 
      Response.json ssl_socket `RequestEntityTooLarge []
	(Json.Object [ "error" , Json.String (!! "Header may not exceed %d bytes" config.max_header_size) ] ) ;
      return () 
    | Request.BodyTooLong -> 
      Response.json ssl_socket `RequestEntityTooLarge []
	(Json.Object [ "error" , Json.String (!! "Body may not exceed %d bytes" config.max_body_size) ] ) ;
      return () 
    | Request.SyntaxError reason ->
      Response.json ssl_socket `BadRequest []
	(Json.Object [ "error" , Json.String ("Could not parse HTTP request: " ^ reason) ] ) ;
      return () 
    | Request.NotImplemented verb -> 
      Response.json ssl_socket `NotImplemented []
	(Json.Object [ "error", Json.String ("Method " ^ verb ^ " is not supported.") ] ) ;
      return () 

  with exn -> 
    (* TODO: deal with errors properly. *)
    return () 

  
