(* © 2014 RunOrg *)

open Std

val create : 
  CId.t option ->
  from:CId.t -> 
  subject:Unturing.t ->
  ?text:Unturing.t ->
  ?html:Unturing.t ->
  ?custom:Json.t ->
  ?urls:String.Url.t list -> 
  ?self:(I.t -> String.Url.t) -> 
  MailAccess.Audience.t -> (#O.ctx, [ `NeedAccess of Id.t
				    | `OK of I.t * Cqrs.Clock.t ]) Run.t
