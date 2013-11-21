(* © 2013 RunOrg *)

open Std
open Common

type status = 
  [ `OK 
  | `BadRequest
  | `RequestEntityTooLarge 
  | `NotImplemented 
  | `NotFound
  | `Forbidden
  | `MethodNotAllowed 
  | `Accepted ]

type t = {
  headers : (string * string) list ;
  body : string ; 
  status : status ;
  request : Request.t option ; 
}

(* The names of the status codes. *)
let status = function
  | `OK -> "200 OK"
  | `Accepted -> "202 Accepted"
  | `BadRequest -> "400 Bad Request" 
  | `Forbidden -> "403 Forbidden"
  | `NotFound -> "404 Not Found"
  | `MethodNotAllowed -> "405 Method Not Allowed"
  | `RequestEntityTooLarge -> "413 Request Entity Too Large"
  | `NotImplemented -> "501 Not Implemented"

(* Raw response function, merely formats the individual lines for output. *)
let send ssl_socket response = 

  let content_length = String.length response.body in 
  let headers = ("Content-Length", string_of_int content_length) :: response.headers in 

  (match response.request with None -> () | Some request -> 
    Log.trace "%s /%s %s %d"
      (verb (request # verb))
      (String.concat "/" (request # path))
      (fst (String.split (status response.status) " "))
      (content_length)) ;

  let b = Buffer.create 1024 in 
  Buffer.add_string b (!! "HTTP/1.1 %s\r\n" (status response.status)) ;
  List.iter (fun (k,v) -> Buffer.add_string b (!! "%s: %s\r\n" k v)) headers ;
  Buffer.add_string b "\r\n" ;
  Buffer.add_string b response.body ;
  Ssl.output_string ssl_socket (Buffer.contents b) ;
  Unix.shutdown (Ssl.file_descr_of_socket ssl_socket) Unix.SHUTDOWN_ALL 

(* Response function that adds a content-type header and formats the output as
   JSON. *)

let json headers status body = {
  status ;
  request = None ;
  body = Json.serialize body ;  
  headers = ( "Content-Type", "application/json" ) :: headers
}

let for_request request response = 
  { response with request = Some request }

(* Response builders
   ================= *)

module Make = struct

  let error status error = 
    json [] status (Json.Object [ "error", Json.String error ]) 

  let json ?(headers=[]) ?(status=`OK) body = 
    json headers status body 

end
