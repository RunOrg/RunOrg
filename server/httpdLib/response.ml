(* © 2014 RunOrg *)

open Std
open Common


(* Request parser logging 
   ====================== *)

let log_enabled = false

(* Response types 
   ============== *)

exception Timeout

type time = float

type status = 
  [ `OK 
  | `BadRequest
  | `RequestEntityTooLarge 
  | `NotImplemented 
  | `Unauthorized
  | `NotFound
  | `Forbidden
  | `MethodNotAllowed 
  | `Accepted 
  | `NotModified
  | `ServiceUnavailable
  | `InternalServerError ]

type t = {
  headers : (string * string) list ;
  body : string ; 
  status : status ;
  request : Request.t option ; 
  started : time option ; 
}

(* Sending a response 
   ================== *)

(* The names of the status codes. *)
let status = function
  | `OK -> "200 OK"
  | `Accepted -> "202 Accepted"
  | `NotModified -> "304 Not Modified" 
  | `BadRequest -> "400 Bad Request" 
  | `Unauthorized -> "401 Unauthorized"
  | `Forbidden -> "403 Forbidden"
  | `NotFound -> "404 Not Found"
  | `MethodNotAllowed -> "405 Method Not Allowed"
  | `RequestEntityTooLarge -> "413 Request Entity Too Large"
  | `InternalServerError -> "500 Internal Server Error"
  | `NotImplemented -> "501 Not Implemented"
  | `ServiceUnavailable -> "503 Service Unavailable"

(* Raw response function, merely formats the individual lines for output. *)
let send ssl_socket config response = 

  let content_length = String.length response.body in 
  let headers = ("Content-Length", string_of_int content_length) :: response.headers in 

  let b = Buffer.create 1024 in 
  Buffer.add_string b (!! "HTTP/1.1 %s\r\n" (status response.status)) ;
  List.iter (fun (k,v) -> Buffer.add_string b (!! "%s: %s\r\n" k v)) headers ;
  Buffer.add_string b "\r\n" ;
  Buffer.add_string b response.body ;

  let output = Buffer.contents b in 
  let size = String.length output in 

  let timeout = Unix.gettimeofday () +. config.max_duration in 

  let rec send retries i = 

    if i = size then return () else
    
      let amount = min 2048 (size - i) in
      let l = try Ssl.write ssl_socket output i amount with Ssl.Write_error Ssl.Error_want_write -> 0 in
      let i = i + l in 
      let now = Unix.gettimeofday () in 
      
      if log_enabled then 
	Log.trace "Wrote %d (total %d/%d): \n%s" l i size
	  (String.sub output (i-l) l) ;
      
      if l <> 0 then 
	send retries i 
      else if now > timeout then
	raise Timeout
      else
	let! () = Run.sleep (delay retries timeout now) in
	send (retries + 1) i

  in

  let! () = send 0 0 in 
   
  let () = match response.request with None -> () | Some request -> 
    Log.trace "%s%s /%s %s %d%s"
      (if trace_requests then Ssl.string_of_socket ssl_socket ^ " | " else "")
      (verb (request # verb))
      (String.concat "/" (request # path))
      (fst (String.split (status response.status) " "))
      (content_length)
      (match response.started with None -> "" | Some t -> !! " %.2fms" (1000. *.(Unix.gettimeofday () -. t)))
  in
  
  let () = Unix.shutdown (Ssl.file_descr_of_socket ssl_socket) Unix.SHUTDOWN_ALL in
  
  return () 
    
(* Response function that adds a content-type header and formats the output as
   JSON. *)

let json headers status body = {
  status ;
  request = None ;
  body = Json.serialize body ;  
  headers = ( "Content-Type", "application/json" ) :: headers ;
  started = None ;
}

let for_request time request response = 
  { response with request = Some request ; started = Some time }

(* Response builders
   ================= *)

module Make = struct

  let error time status error = 
    { json [] status (Json.Object [ "error", Json.String error ]) with started = Some time }

  let tryLater time delay reason = 
    { json [ "Retry-After", string_of_int delay ] `ServiceUnavailable (Json.Object reason) 
      with started = Some time }

  let json ?(headers=[]) ?(status=`OK) body = 
    json headers status body 

  let raw ?(headers=[]) ?(status=`OK) body = {
    status ;
    request = None ;
    body ;
    headers ; 
    started = None ;
  }

end
