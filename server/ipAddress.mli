(* © 2014 RunOrg *)

(** IP Addresses (with port), serializable to JSON or to a database. *)
include Fmt.FMT

val of_inet_addr : Unix.inet_addr -> int -> t

val of_sockaddr : Unix.sockaddr -> t

(** Prints a human-readable version of an IP address. IPv6 may or may not use
    the compat format. *)
val to_string : t -> string
