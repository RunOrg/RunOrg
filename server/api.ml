(* © 2013 RunOrg *)

open Std

include ApiLib

let config = Httpd.(Configuration.Httpd.({ 
  port ; 
  key_path ; 
  certificate_path ; 
  key_password ;
  max_header_size ;
  max_body_size ;
})) 

let run () = 
  Httpd.start config (fun req -> Run.with_context (new O.ctx) (Endpoint.dispatch req))
