(* © 2014 RunOrg *)

val reset : SqlConnection.config -> unit

exception Shutdown

val heartbeat : SqlConnection.config -> unit Run.thread

