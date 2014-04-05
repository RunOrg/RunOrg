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
  max_duration ; 
})) 

let run () = 
  Httpd.start config (fun req -> 

    let ctx = new O.ctx in

    let ctx = match req # at with None -> ctx | Some clock -> ctx # with_after clock in 

    Run.with_context ctx (Endpoint.dispatch req))
