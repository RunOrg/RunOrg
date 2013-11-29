(* © 2013 RunOrg *)

open TplToken
open TplGen

let result = 
  print_endline (Explore.to_string (Explore.explore Cli.source_directory))
