(* © 2014 RunOrg *)

val create : 
  ?label:string -> 
  ?id:CustomId.t -> 
  unit -> (#O.ctx, I.t * Cqrs.Clock.t) Run.t

