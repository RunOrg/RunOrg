(* © 2014 RunOrg *)

val auth_persona : string -> (# O.ctx, ([`Contact] Token.I.id * Queries.short * Cqrs.Clock.t) option) Run.t
