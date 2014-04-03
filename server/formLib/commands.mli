(* © 2014 RunOrg *)

open Std

val create :
  ?label:String.Label.t ->
  ?id:CustomId.t -> 
  Owner.t ->
  Json.t -> 
  Field.t list -> (#O.ctx, I.t option * Cqrs.Clock.t) Run.t

val fill : 
  I.t ->
  FilledI.t -> 
  (Field.I.t, Json.t) Map.t -> (#O.ctx, (Cqrs.Clock.t, Error.t) result) Run.t

