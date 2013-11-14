(* © 2013 RunOrg *)

open Std

type status = 
  [ `OK 
  | `BadRequest
  | `RequestEntityTooLarge 
  | `NotImplemented ]

(* The names of the status codes. *)
let status = function
  | `OK -> "200 OK"
  | `BadRequest -> "400 Bad Request" 
  | `RequestEntityTooLarge -> "413 Request Entity Too Large"
  | `NotImplemented -> "501 Not Implemented"

(* Raw response function, merely formats the individual lines for output. *)
let string ssl_socket code headers body = 

  let content_length = String.length body in 
  let headers = ("Content-Length", string_of_int content_length) :: headers in 

  let b = Buffer.create 1024 in 
  Buffer.add_string b (!! "HTTP/1.1 %s\r\n" (status code)) ;
  List.iter (fun (k,v) -> Buffer.add_string b (!! "%s: %s\r\n" k v)) headers ;
  Buffer.add_string b "\r\n" ;
  Buffer.add_string b body ;
  Ssl.output_string ssl_socket (Buffer.contents b) ;
  Log.trace "%s" (Buffer.contents b) ; 
  Unix.shutdown (Ssl.file_descr_of_socket ssl_socket) Unix.SHUTDOWN_ALL 

(* Response function that adds a content-type header and formats the output as
   JSON. *)

let json ssl_socket code headers body = 
  string ssl_socket code ( ("Content-Type","application/json") :: headers ) 
    (Json.serialize body) 

(* Response function that adds a content-type header and formats the output as
   MSGPACK (from a JSON block of data) *)

let json_msgpack ssl_socket code headers body = 
  string ssl_socket code ( ("Content-Type","application/x-msgpack") :: headers )
    (Pack.to_string Json.pack body) 
