(* © 2013 RunOrg *)

open Std

let config = Httpd.({ port = 4443 ; key = "" }) 

let run () = 
  Httpd.start config (fun req res -> return res) 
