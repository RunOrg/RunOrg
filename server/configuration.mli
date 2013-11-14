(* © 2013 RunOrg *)

type role = [ `Bot | `Web | `Reset ]

val role : role

val log_prefix : string

module Database : sig
  val host : string
  val port : int
  val database : string
  val user : string
  val password : string
end
