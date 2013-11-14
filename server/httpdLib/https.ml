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

exception HeaderTooLong
exception BodyTooLong

(* Reads the entire request out of a socket, returns the raw header and the raw footer. *)
let read_request config ssl_socket = 
  
  (* Read the entire header in one go. *)
  let header = String.create config.max_header_size in 
  let l = Ssl.read ssl_socket header 0 config.max_header_size in

  (* Look for a header termination... *)
  let pos = try String.find header "\r\n\r\n" with _ -> raise HeaderTooLong in
  let clean_header = String.sub header 0 pos in 

  (* A body is expected if the header starts with POST or PUT. *)
  if String.starts_with clean_header "POST" || String.starts_with clean_header "PUT" then begin

    let body = Buffer.create 1024 in
    let bufsize = 1024 in
    let buffer = String.create 1024 in

    let rec read_more () = 
      if Buffer.length body <= config.max_body_size then begin
	let l = Ssl.read ssl_socket buffer 0 bufsize in
	Buffer.add_substring body buffer 0 l ;
	if l = bufsize then read_more () 
      end
    in

    (* For some reason, there was a little bit of body at the end of the header... *)
    if l - pos > 4 then ( 
      Buffer.add_string body (String.sub header (pos + 4) (l - pos + 4)) ;
      if l = config.max_header_size then read_more ()) 
    else
      read_more () ;

    clean_header, Some (Buffer.contents body)

  end else
    
    clean_header, None

let parse context socket config handler = 
  try
    let ssl_socket = Ssl.embed_socket socket context in
    Ssl.accept ssl_socket ;   
    try 
      let head, body = read_request config ssl_socket in
      Log.trace "HEAD: %s" head ;
      let () = Response.string ssl_socket `OK [] "OK!" in
      return () 
    with 
    | HeaderTooLong -> 
      Response.json ssl_socket `RequestEntityTooLarge []
	(Json.Object [ "error" , Json.String (!! "Header may not exceed %d bytes" config.max_header_size) ] ) ;
      return () 
    | BodyTooLong -> 
      Response.json ssl_socket `RequestEntityTooLarge []
	(Json.Object [ "error" , Json.String (!! "Body may not exceed %d bytes" config.max_body_size) ] ) ;
      return () 
  with exn -> 
    (* TODO: deal with errors properly. *)
    return () 

  
