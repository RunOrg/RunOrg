(* © 2014 RunOrg *)

open Std

val create : 
  CId.t option ->
  from:CId.t -> 
  subject:String.Label.t ->
  ?text:string ->
  ?html:String.Rich.t ->
  ?custom:Json.t ->
  ?urls:String.Url.t list -> 
  MailAccess.Audience.t -> (#O.ctx, [ `NeedAccess of Id.t
				    | `OK of I.t * Cqrs.Clock.t ]) Run.t
