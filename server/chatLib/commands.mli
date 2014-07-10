(* © 2014 RunOrg *)

open Std

val create : ?subject:String.Label.t -> PId.t list -> GId.t list -> (#O.ctx, I.t * Cqrs.Clock.t) Run.t
val createPublic : String.Label.t option -> (#O.ctx, I.t * Cqrs.Clock.t) Run.t
val delete : I.t -> (#O.ctx, Cqrs.Clock.t) Run.t
val post : I.t -> PId.t -> String.Rich.t -> (#O.ctx, MI.t * Cqrs.Clock.t) Run.t
val deleteItem : I.t -> MI.t -> (#O.ctx, Cqrs.Clock.t) Run.t
