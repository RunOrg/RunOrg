(* © 2014 RunOrg *)

open Std

val create : 
  ?label:String.Label.t -> 
  ?id:CustomId.t -> 
  unit -> (#O.ctx, [ `OK of I.t * Cqrs.Clock.t
		   | `AlreadyExists of CustomId.t ]) Run.t

val add : CId.t list -> I.t list -> (#O.ctx, Cqrs.Clock.t) Run.t

val remove : CId.t list -> I.t list -> (#O.ctx, Cqrs.Clock.t) Run.t

val delete : I.t -> (#O.ctx, Cqrs.Clock.t) Run.t
