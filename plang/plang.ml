(* © 2013 RunOrg *)

open TplToken
open TplGen

let result = 
  print_endline (Build.build (Explore.explore Cli.source_directory)).Build.js

