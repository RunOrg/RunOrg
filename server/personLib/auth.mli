(* © 2014 RunOrg *)

val auth_persona : string -> (# O.ctx, ([`Person] Token.I.id * Queries.short * Cqrs.Clock.t) option) Run.t
