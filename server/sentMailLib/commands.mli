(* © 2014 RunOrg *)

val send :
  CId.t option -> 
  Mail.I.t ->
  GId.t -> (#O.ctx, [ `NeedAccess of Id.t
		    | `NoSuchMail of Mail.I.t
		    | `OK of I.t * Cqrs.Clock.t ]) Run.t
  
val follow : Link.t -> (#O.ctx, [ `NotFound of Link.t * Id.t
				| `Auth of Token.I.t * string
				| `Link of string
				| `Track ])  Run.t
