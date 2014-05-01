(* © 2014 RunOrg *)

open Std

val create : 
  PId.t option -> 
  ?label:String.Label.t -> 
  ?id:CustomId.t -> 
  GroupAccess.Audience.t -> (#O.ctx, [ `OK of GId.t * Cqrs.Clock.t
				     | `NeedAccess of Id.t
				     | `AlreadyExists of CustomId.t ]) Run.t

val add_forced : PId.t list -> GId.t list -> (#O.ctx, Cqrs.Clock.t) Run.t

val add : PId.t option -> PId.t list -> GId.t list -> (#O.ctx, [ `OK of Cqrs.Clock.t
							       | `NeedModerator of GId.t  
							       | `MissingPerson of PId.t
							       | `NotFound of GId.t ]) Run.t


val remove : PId.t option -> PId.t list -> GId.t list -> (#O.ctx, [ `OK of Cqrs.Clock.t
								  | `NeedModerator of GId.t
								  | `NotFound of GId.t ]) Run.t

val delete : PId.t option -> GId.t -> (#O.ctx, [ `OK of Cqrs.Clock.t
					       | `NeedAdmin of GId.t 
					       | `NotFound of GId.t ]) Run.t
