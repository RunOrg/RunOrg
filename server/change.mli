(* © 2014 RunOrg *)

type 'a t = [ `Keep | `Set of 'a ]

val apply : 'a t -> 'a -> 'a

val of_field : string -> [ `JSON of Json.t | `Raw of string ] option -> 'a option -> 'a option t

val of_option : 'a option -> 'a t
