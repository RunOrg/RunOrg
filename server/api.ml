(* © 2013 RunOrg *)

open Std

let config = Httpd.(Configuration.Httpd.({ 
  port ; 
  key_path ; 
  certificate_path ; 
  key_password ;
  max_header_size ;
  max_body_size ;
})) 

let run () = 
  Httpd.start config (fun req res -> return res) 
