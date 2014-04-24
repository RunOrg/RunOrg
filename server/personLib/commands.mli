(* © 2014 RunOrg *)

open Std

val create : 
  ?name:String.Label.t -> 
  ?givenName:String.Label.t -> 
  ?familyName:String.Label.t -> 
  ?gender:[`F|`M] -> 
  String.Label.t -> (# O.ctx, PId.t * Cqrs.Clock.t) Run.t

