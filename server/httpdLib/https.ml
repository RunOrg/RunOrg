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

let send500 req exn = 
  Log.error "In /%s: %s" (String.concat "/" (req # path)) (Printexc.to_string exn) ;
  return (Response.Make.error `InternalServerError "Server encountered an unexpected error")

let parse context socket config handler = 
  try
    let ssl_socket = Ssl.embed_socket socket context in
    Ssl.accept ssl_socket ;   
    let! response = 
      try 
	let  request = Request.parse config ssl_socket in
	let! response = Run.on_failure (send500 request) (handler request) in 
	return (Response.for_request request response)
      with 

      | Request.HeaderTooLong -> 
	return (Response.Make.error `RequestEntityTooLarge
		  (!! "Header may not exceed %d bytes" config.max_header_size)) ;

      | Request.BodyTooLong -> 
	return (Response.Make.error `RequestEntityTooLarge
		  (!! "Body may not exceed %d bytes" config.max_body_size)) ;

      | Request.SyntaxError reason ->
	return (Response.Make.error `BadRequest 
		  ("Could not parse HTTP request: " ^ reason)) ;

      | Request.NotImplemented verb -> 
	return (Response.Make.error `NotImplemented 
		  ("Method " ^ verb ^ " is not supported.")) ;	
    in

    return ( Response.send ssl_socket response )
    
  with exn -> 
    
    (* TODO: deal with errors properly. *)
    return () 

  
