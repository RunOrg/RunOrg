(* © 2014 RunOrg *)

val send :
  CId.t option -> 
  Mail.I.t ->
  GId.t -> (#O.ctx, [ `NeedAccess of Id.t
		    | `NoSuchMail of Mail.I.t
		    | `NoSuchGroup of GId.t
		    | `GroupEmpty of GId.t
		    | `OK of I.t * int * Cqrs.Clock.t ]) Run.t
  
val follow : Link.t -> (#O.ctx, [ `NotFound of Link.t * Id.t
				| `Auth of Token.I.t * string
				| `Link of string
				| `Track ])  Run.t
