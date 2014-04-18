(* © 2014 RunOrg *)

type script 

val compile : string -> Json.t list -> [ `OK of script | `SyntaxError of string * int * int ]

