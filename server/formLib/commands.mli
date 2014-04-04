(* © 2014 RunOrg *)

open Std

val create :
  CId.t option -> 
  ?label:String.Label.t ->
  ?id:CustomId.t -> 
  owner:Owner.t ->
  audience:FormAccess.Audience.t -> 
  custom:Json.t -> 
  Field.t list -> (#O.ctx, [ `OK of I.t * Cqrs.Clock.t
			   | `NeedAccess of Id.t
			   | `AlreadyExists of CustomId.t ] ) Run.t

val update : 
  ?label:String.Label.t option ->
  ?owner:Owner.t ->
  ?audience:FormAccess.Audience.t ->
  ?custom:Json.t ->
  ?fields:Field.t list ->
  CId.t option -> 
  I.t -> (# O.ctx, [ `OK of Cqrs.Clock.t
		   | `NoSuchForm of I.t  
		   | `NeedAdmin of I.t
		   | `FormFilled of I.t ] ) Run.t
val fill : 
  CId.t option ->
  I.t ->
  FilledI.t -> 
  (Field.I.t, Json.t) Map.t -> (#O.ctx, (Cqrs.Clock.t, Error.t) result) Run.t

