(* © 2014 RunOrg *)

open Std

val create : ?subject:String.Label.t -> CId.t list -> Group.I.t list -> (#O.ctx, I.t * Cqrs.Clock.t) Run.t
val createPM : CId.t -> CId.t -> (#O.ctx, I.t * Cqrs.Clock.t) Run.t
val delete : I.t -> (#O.ctx, Cqrs.Clock.t) Run.t
val post : I.t -> CId.t -> String.Rich.t -> (#O.ctx, MI.t * Cqrs.Clock.t) Run.t
val deleteItem : I.t -> MI.t -> (#O.ctx, Cqrs.Clock.t) Run.t
