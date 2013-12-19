(* © 2013 RunOrg *)

(** Compile all JS source files to a single JavaScript file. *)

(** Receives a list of all JavaScript file contents, in the correct order, 
    and the list of variables to be inserted. Outputs a concatenated string. *)
val compile : string list -> (string * string) list -> string 
