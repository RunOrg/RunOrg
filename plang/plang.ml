(* © 2013 RunOrg *)

open TplToken

let result = 
  print_endline (Explore.to_string (Explore.explore Cli.source_directory))
