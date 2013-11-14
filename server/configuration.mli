(* © 2013 RunOrg *)

type role = [ `Bot | `Web | `Reset ]

(** The role of this instance, as parsed from the command line. *)
val role : role

(** If set, write logs to a file in that folder. Otherwise, write logs to 
    standard output. *)
val log_prefix : string option

module Database : sig
  val host : string
  val port : int
  val database : string
  val user : string
  val password : string
end

(** The list of all super-administrator emails loaded from configuration. *)
val admins : string list

module Httpd : sig
  val port : int
  val key_path : string 
  val certificate_path : string
  val key_password : string
end
