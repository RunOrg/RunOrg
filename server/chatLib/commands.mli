(* © 2014 RunOrg *)

open Std

val create : ?subject:String.Label.t -> PId.t list -> GId.t list -> (#O.ctx, I.t * Cqrs.Clock.t) Run.t
val createPublic : String.Label.t option -> (#O.ctx, I.t * Cqrs.Clock.t) Run.t
val delete : I.t -> (#O.ctx, Cqrs.Clock.t) Run.t
val createPost : I.t -> PId.t -> String.Rich.t -> (#O.ctx, PostI.t * Cqrs.Clock.t) Run.t
val deletePost : I.t -> PostI.t -> (#O.ctx, Cqrs.Clock.t) Run.t
