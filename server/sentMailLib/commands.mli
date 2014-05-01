(* © 2014 RunOrg *)

open Std

val send :
  PId.t option -> 
  Mail.I.t ->
  GId.t -> (#O.ctx, [ `NeedAccess of Id.t
		    | `NoSuchMail of Mail.I.t
		    | `NoSuchGroup of GId.t
		    | `GroupEmpty of GId.t
		    | `OK of I.t * int * Cqrs.Clock.t ]) Run.t
  
val follow : Link.t -> IpAddress.t -> (#O.ctx, [ `NotFound of Link.t * Id.t
					       | `Auth of Token.I.t * String.Url.t
					       | `Link of String.Url.t
					       | `Track ])  Run.t
