(* © 2014 RunOrg *)

open Std

type 'ctx creator = 
  ?name:String.Label.t -> 
  ?givenName:String.Label.t -> 
  ?familyName:String.Label.t -> 
  ?gender:[`F|`M] -> 
  String.Label.t -> ('ctx, PId.t * Cqrs.Clock.t) Run.t

val create_forced : #O.ctx creator

val import : PId.t option -> (#O.ctx as 'ctx, [ `OK of 'ctx creator | `NeedAccess of Id.t ]) Run.t

val update : 
  PId.t option -> 
  name:String.Label.t option Change.t ->
  givenName:String.Label.t option Change.t ->
  familyName:String.Label.t option Change.t ->
  gender:[`F|`M] option Change.t ->
  email:String.Label.t Change.t ->
  PId.t -> (#O.ctx, [ `OK of Cqrs.Clock.t
		    | `NotFound of PId.t 
		    | `NeedAccess of Id.t ]) Run.t
