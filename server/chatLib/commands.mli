(* © 2014 RunOrg *)

val create : CId.t list -> Group.I.t list -> (#O.ctx, I.t * Cqrs.Clock.t) Run.t
val createPM : CId.t -> CId.t -> (#O.ctx, I.t * Cqrs.Clock.t) Run.t
val delete : I.t -> (#O.ctx, Cqrs.Clock.t) Run.t
