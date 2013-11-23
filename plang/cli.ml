(* © 2013 RunOrg *)

let () = 
  if Array.length Sys.argv < 3 then (
    print_endline "Usage: plang source output" ;
    exit(-1)
  )

let source_directory = 
  Sys.argv.(1)

let output_directory = 
  Sys.argv.(2)

    
