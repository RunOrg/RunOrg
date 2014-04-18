(* © 2014 RunOrg *)

type script = Ast.t

val compile : string -> Json.t list -> [ `OK of script | `SyntaxError of string * int * int ]

