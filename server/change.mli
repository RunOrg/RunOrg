(* © 2014 RunOrg *)

type 'a t = [ `Keep | `Set of 'a ]

val apply : 'a t -> 'a -> 'a
