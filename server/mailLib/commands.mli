(* © 2014 RunOrg *)

val create : 
  CId.t option ->
  from:CId.t -> 
  subject:string ->
  ?text:string ->
  ?html:string ->
  MailAccess.Audience.t -> (#O.ctx, I.t * Cqrs.Clock.t) Run.t
