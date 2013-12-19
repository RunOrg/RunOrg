(* © 2013 RunOrg *)

open TplToken
open TplGen

let result = 
  Output.write Cli.output_directory (Build.build (Explore.explore Cli.source_directory))

