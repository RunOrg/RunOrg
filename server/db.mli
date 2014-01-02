(* © 2013 RunOrg *)

(** A database, in the RunOrg sense, is the space where all other objects live
    (with a few server-level exceptions, such as server-admins). *)

(** Create a new database, with the provided name. *)
val create : [`ServerAdmin] Token.I.id -> string -> (# Cqrs.ctx, Id.t * Cqrs.Clock.t) Run.t

(** Return the number of created, not-yet-deleted databases on the server. *)
val count : [`ServerAdmin] Token.I.id -> (# Cqrs.ctx, int) Run.t

(** Return a subset of all databases, ordered by identifier. Maximum count is [100000]. *)
val all : 
  limit:int ->
  offset:int ->
  [`ServerAdmin] Token.I.id ->
  (# Cqrs.ctx, < id : Id.t ; label : string ; created : Time.t > list) Run.t

