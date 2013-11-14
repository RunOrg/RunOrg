(* © 2013 RunOrg *)

type request = unit
type response = unit

type 'ctx handler = request -> response -> ('ctx, response) Run.t

type config = { 
  port: int ; 
  key_path : string ; 
  key_password : string ; 
  certificate_path : string ; 
  max_header_size : int ;
  max_body_size : int ; 
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
