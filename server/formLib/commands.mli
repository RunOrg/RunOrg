(* © 2014 RunOrg *)

open Std

val create :
  ?label:String.Label.t ->
  ?id:CustomId.t -> 
  Owner.t ->
  FormAccess.Audience.t -> 
  Json.t -> 
  Field.t list -> (#O.ctx, I.t option * Cqrs.Clock.t) Run.t

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
  I.t ->
  FilledI.t -> 
  (Field.I.t, Json.t) Map.t -> (#O.ctx, (Cqrs.Clock.t, Error.t) result) Run.t

