(* © 2014 RunOrg *)

open Std

val create :
  PId.t option -> 
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
  PId.t option -> 
  I.t -> (# O.ctx, [ `OK of Cqrs.Clock.t
		   | `NoSuchForm of I.t  
		   | `NeedAdmin of I.t
		   | `FormFilled of I.t ] ) Run.t
val fill : 
  PId.t option ->
  I.t ->
  FilledI.t -> 
  (Field.I.t, Json.t) Map.t -> (#O.ctx, [ `OK of Cqrs.Clock.t
					| `NoSuchForm of I.t
					| `NoSuchField of I.t * Field.I.t
					| `MissingRequiredField of I.t * Field.I.t
					| `InvalidFieldFormat of I.t * Field.I.t * Field.Kind.t
					| `NoSuchOwner of I.t * FilledI.t 
					| `NeedAdmin of I.t * FilledI.t
					]) Run.t

