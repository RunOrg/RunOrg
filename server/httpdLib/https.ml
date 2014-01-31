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
    Log.error "In /%s: %s" (String.concat "/" (req # path)) (Printexc.to_string exn) ;
    return (Response.Make.error time `InternalServerError "Server encountered an unexpected error")

let handle_request_failure config time = function 
  | Request.HeaderTooLong -> 
    return (Response.Make.error time `RequestEntityTooLarge
	      (!! "Header may not exceed %d bytes" config.max_header_size)) ;
    
  | Request.BodyTooLong -> 
    return (Response.Make.error time `RequestEntityTooLarge
	      (!! "Body may not exceed %d bytes" config.max_body_size)) ;
    
  | Request.SyntaxError reason ->
    return (Response.Make.error time `BadRequest 
	      ("Could not parse HTTP request: " ^ reason)) ;
    
  | Request.NotImplemented verb -> 
    return (Response.Make.error time `NotImplemented 
	      ("Method " ^ verb ^ " is not supported.")) ;	
    
  | exn -> raise exn


(* Parsing and processing a request
   ================================ *)

let parse context socket config handler = 
  try   

    let time = Unix.gettimeofday () in

    if trace_requests then 
      Log.trace "%s | Request received" 
	(match Unix.getpeername socket with 
	| Unix.ADDR_UNIX str -> str
	| Unix.ADDR_INET (inet,port) -> !! "%s:%d" (Unix.string_of_inet_addr inet) port) ; 
	
    (* Wrap the socket in an SSL context. This will cause a negotiation to happen. *)
    let ssl_socket = Ssl.embed_socket socket context in

    if trace_requests then 
      Log.trace "%s | SSL established %.2fms" (Ssl.string_of_socket ssl_socket) 
	(1000. *. (Unix.gettimeofday () -. time)) ; 

    Ssl.accept ssl_socket ;

    if trace_requests then 
      Log.trace "%s | SSL accepted %.2fms" (Ssl.string_of_socket ssl_socket) 
	(1000. *. (Unix.gettimeofday () -. time)) ; 

    (* To avoid locking up a thread, all socket operations are non-blocking. *)
    Unix.set_nonblock socket ;

    let! response = Run.on_failure (handle_request_failure config time) begin

      let! request  = Request.parse config ssl_socket in

      let () = if trace_requests then 
	  Log.trace "%s | Request parsed %.2fms" (Ssl.string_of_socket ssl_socket) 
	    (1000. *. (Unix.gettimeofday () -. time)) in 
	
      let! response = Run.on_failure (handle_action_failure time request) (handler request) in 

      return (Response.for_request time request response)	

    end in

    return ( Response.send ssl_socket response )
    
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
    
