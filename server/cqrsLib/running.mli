(* © 2014 RunOrg *)

val reset : Common.config -> unit

exception Shutdown

val heartbeat : Common.config -> unit Run.thread

