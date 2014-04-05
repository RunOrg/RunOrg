(* © 2014 RunOrg *)

open Std

val create : 
  ?label:String.Label.t -> 
  ?id:CustomId.t -> 
  CId.t option -> (#O.ctx, [ `OK of GId.t * Cqrs.Clock.t
		   | `NeedAccess of Id.t
		   | `AlreadyExists of CustomId.t ]) Run.t

val add : CId.t list -> GId.t list -> (#O.ctx, Cqrs.Clock.t) Run.t

val remove : CId.t list -> GId.t list -> (#O.ctx, Cqrs.Clock.t) Run.t

val delete : GId.t -> (#O.ctx, Cqrs.Clock.t) Run.t
