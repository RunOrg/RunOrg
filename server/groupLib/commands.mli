(* © 2014 RunOrg *)

val create : 
  ?label:string -> 
  ?id:CustomId.t -> 
  unit -> (#O.ctx, I.t * Cqrs.Clock.t) Run.t

val add : CId.t list -> I.t list -> (#O.ctx, Cqrs.Clock.t) Run.t

val remove : CId.t list -> I.t list -> (#O.ctx, Cqrs.Clock.t) Run.t

val delete : I.t -> (#O.ctx, Cqrs.Clock.t) Run.t
