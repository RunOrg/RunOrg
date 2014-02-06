(* © 2013 RunOrg *)

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
  match Unix.getpeername (Ssl.file_descr_of_socket ssl_socket) with
  | Unix.ADDR_UNIX str -> "local:" ^ str
  | Unix.ADDR_INET (addr,_) -> Unix.string_of_inet_addr addr

let verb = function
  | `GET -> "GET"
  | `POST -> "POST"
  | `PUT -> "PUT"
  | `DELETE -> "DELETE"    

let trace_requests = false

let delay retries timeout now =     
  min (float_of_int (retries + 1) *. 10.) ((timeout -. now) /. 2. *. 1000.)

