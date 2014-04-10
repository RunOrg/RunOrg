(* © 2013 RunOrg *)

open Std

include ApiLib

let httpd_config = Httpd.(Configuration.Httpd.({ 
  port ; 
  key_path ; 
  certificate_path ; 
  key_password ;
  max_header_size ;
  max_body_size ;
  max_duration ; 
})) 

let cqrs_config = O.config

let run () = 
  Httpd.start httpd_config (fun req -> 
    
    let! oldctx = Run.context in 

    let  mkctx cqrs = 
      let ctx = new O.ctx cqrs oldctx in    
      match req # at with None -> ctx | Some clock -> ctx # with_after clock 
    in

    Cqrs.using cqrs_config mkctx begin
      let! ()  = LogReq.trace "Connected to database" in
      Endpoint.dispatch req
    end)
