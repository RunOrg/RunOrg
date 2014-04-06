(* © 2014 RunOrg *)

type config = { 
  port: int ; 
  key_path : string ; 
  key_password : string ; 
  certificate_path : string ; 
  max_header_size : int ;
  max_body_size : int ; 
  max_duration : float ; 
}

let ip ssl_socket = 
  IpAddress.of_sockaddr (Unix.getpeername (Ssl.file_descr_of_socket ssl_socket))

let verb = function
  | `GET -> "GET"
  | `POST -> "POST"
  | `PUT -> "PUT"
  | `DELETE -> "DELETE"    

let trace_requests = LogReq.enabled

let delay retries timeout now =     
  min (float_of_int (retries + 1) *. 10.) ((timeout -. now) /. 2. *. 1000.)

