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

