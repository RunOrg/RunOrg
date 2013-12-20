(* © 2013 RunOrg *)

(** A database, in the RunOrg sense, is the space where all other objects live
    (with a few server-level exceptions, such as server-admins). *)

(** Create a new database, with the provided name. *)
val create : [`ServerAdmin] Token.I.id -> string -> (# Cqrs.ctx, Id.t * Cqrs.Clock.t) Run.t

