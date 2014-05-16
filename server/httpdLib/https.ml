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

(* Failure handlers 
   ================ *)

let handle_action_failure time req = function  
  | Cqrs.Projection.LeftBehind (proj,current,at) ->
    return (Response.Make.tryLater time 1
	      [ "error", Json.String "Data is not yet available for the 'at' you specified. Try again later." ;
		"projection", Json.String proj ;
		"current", Cqrs.Clock.to_json current ;
		"expected", Cqrs.Clock.to_json at ])
  | exn -> 
    Log.error "In %s: %s" (Request.to_string req) (Printexc.to_string exn) ;
    return (Response.Make.error time `InternalServerError "Server encountered an unexpected error")

let handle_request_failure config time = function 
  | Request.HeaderTooLong -> 
    return (Response.Make.error time `RequestEntityTooLarge
	      (!! "Header may not exceed %d bytes" config.max_header_size)) ;
    
  | Request.BodyTooLong -> 
    return (Response.Make.error time `RequestEntityTooLarge
	      (!! "Body may not exceed %d bytes" config.max_body_size)) ;

  | Request.Timeout -> 
    return (Response.Make.error time `BadRequest "Timed out while waiting for input")
    
  | Request.SyntaxError reason ->
    return (Response.Make.error time `BadRequest 
	      ("Could not parse HTTP request: " ^ reason)) ;
    
  | Request.NotImplemented verb -> 
    return (Response.Make.error time `NotImplemented 
	      ("Method " ^ verb ^ " is not supported.")) 

let handle_response_failure = function 
  | Response.Timeout -> 
    Log.error "Socket timed out during response" ;
    return () 
  | exn ->     
    Log.error "While sending response: %s" (Printexc.to_string exn) ;
    raise exn


(* Parsing and processing a request
   ================================ *)

let parse context socket config handler = 
  try   

    let time = Unix.gettimeofday () in

    let! () = LogReq.set_request_ip 
      (match Unix.getpeername socket with
       | Unix.ADDR_UNIX str -> str
       | Unix.ADDR_INET (inet,port) -> !! "%s:%d" (Unix.string_of_inet_addr inet) port) in

    let! () = LogReq.trace "Request received" in
	
    (* Wrap the socket in an SSL context. This will cause a negotiation to happen. *)
    let ssl_socket = Ssl.embed_socket socket context in

    let! () = LogReq.trace "SSL established" in

    let () = Ssl.accept ssl_socket in

    let! () = LogReq.trace "SSL accepted" in

    (* To avoid locking up a thread, all socket operations are non-blocking. *)
    let () = Unix.set_nonblock socket in

    let! origin, request = Request.parse config ssl_socket in    

    let! response = match request with

      | Ok request -> 
      
	let! () = LogReq.set_request_path (Request.to_string request) in
	let! () = LogReq.trace "HTTP parsed" in
	
	let! response = Run.on_failure (handle_action_failure time request) (handler request) in 
	
	let! () = LogReq.trace "response computed" in
	
	return (Response.for_request time request response)	

      | Bad error -> 
	
	handle_request_failure config time error

    in

    let response = Response.with_CORS origin response in 

    Run.on_failure handle_response_failure 
      (Response.send ssl_socket config response)
    
  with 
  | ( Ssl.Read_error Ssl.Error_syscall
	| Ssl.Accept_error Ssl.Error_syscall
	| Ssl.Write_error Ssl.Error_syscall ) ->

    (* Remote end closed the connection. *)
    return () 

  | ( Ssl.Read_error inner 
	| Ssl.Accept_error inner
	| Ssl.Write_error inner ) as exn ->
	  
    (* TODO: deal with errors properly. *)
    Log.trace "When accepting connection: %s\n  %s\n  %s" 
      (Printexc.to_string exn) 
      (Ssl.string_of_error inner) 
      (Ssl.get_error_string ()) ;

    return () 

  | exn -> 
    
    (* TODO: deal with errors properly. *)
    Log.trace "When accepting connection: %s" 
      (Printexc.to_string exn) ;

    return () 
    
