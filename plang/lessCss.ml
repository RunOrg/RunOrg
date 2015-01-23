(* © 2013 RunOrg *)

let compile input output = 
  let result = Sys.command (Printf.sprintf "lessc %s > %s"
			      (Filename.quote input) (Filename.quote output)) in
  if result <> 0 then exit (-1) ;
  let chan = open_in output in
  let length = in_channel_length chan in 
  close_in chan ; 
  Printf.printf "%s: %d bytes\n%!" output length 
 
