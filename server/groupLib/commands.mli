(* © 2014 RunOrg *)

open Std

val create : 
  CId.t option -> 
  ?label:String.Label.t -> 
  ?id:CustomId.t -> 
  GroupAccess.Audience.t -> (#O.ctx, [ `OK of GId.t * Cqrs.Clock.t
				     | `NeedAccess of Id.t
				     | `AlreadyExists of CustomId.t ]) Run.t

val add : CId.t option -> CId.t list -> GId.t list -> (#O.ctx, Cqrs.Clock.t) Run.t
val add_forced : CId.t list -> GId.t list -> (#O.ctx, Cqrs.Clock.t) Run.t

val remove : CId.t option -> CId.t list -> GId.t list -> (#O.ctx, Cqrs.Clock.t) Run.t

val delete : CId.t option -> GId.t -> (#O.ctx, Cqrs.Clock.t) Run.t
