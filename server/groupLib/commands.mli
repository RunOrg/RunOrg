(* © 2014 RunOrg *)

val create : 
  ?label:string -> 
  ?id:string -> 
  unit -> (#O.ctx, I.t * Cqrs.Clock.t) Run.t

