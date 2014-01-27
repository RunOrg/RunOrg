(* © 2014 RunOrg *)

open Std

val create : 
  ?fullname:String.Label.t -> 
  ?firstname:String.Label.t -> 
  ?lastname:String.Label.t -> 
  ?gender:[`F|`M] -> 
  String.Label.t -> (# O.ctx, CId.t * Cqrs.Clock.t) Run.t

