(* © 2013 RunOrg *)

type role = [ `Bot | `Web | `Reset ]

val role : unit -> role

val log : ('a,unit,string,unit) format4 -> 'a

