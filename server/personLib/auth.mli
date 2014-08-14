(* © 2014 RunOrg *)

open Std

val auth_persona : String.Url.t -> string -> 
  (# O.ctx, [ `OK of [`Person] Token.I.id * Queries.short * Cqrs.Clock.t
	    | `BadAudience of String.Url.t 
	    | `InvalidAssertion ]) Run.t
