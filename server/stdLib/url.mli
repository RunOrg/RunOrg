(* © 2014 RunOrg *)

(** An URL is a string that follows a specific format. *)

include Fmt.FMT

val of_string : string -> t option 

val to_string : t -> string
