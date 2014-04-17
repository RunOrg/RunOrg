(* © 2014 RunOrg *)

open Std

val create : 
  CId.t option ->
  from:CId.t -> 
  subject:String.Label.t ->
  ?text:string ->
  ?html:String.Rich.t ->
  MailAccess.Audience.t -> (#O.ctx, I.t * Cqrs.Clock.t) Run.t
