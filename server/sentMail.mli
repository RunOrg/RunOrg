(* © 2014 RunOrg *)

(** Mail that is sent lives separately from the original. 
    It is accessed in a different pattern (by the receiver, rather
    than the server) and needs to keep large amounts of statistics
    that are not relevant while drafting new mail. *)

(** The identifier of a wave --- a group of e-mails that were sent
    together to different contacts. *)
module I : Id.PHANTOM

(** Start sending a specific e-mail to a group. This will actually 
    cause the e-mails to be sent out. Creates a new wave and returns 
    its identifier. *)
val send :
  CId.t option -> 
  Mail.I.t ->
  GId.t -> (#O.ctx, [ `NeedAccess of Id.t
		    | `NoSuchMail of Mail.I.t
		    | `OK of I.t * Cqrs.Clock.t ]) Run.t
  
(** Information about a mail sent to a specific person. *)
type info = <
  mail : Mail.I.t ;
  to_  : CId.t ; 
  sent : Time.t option ; 
  opened  : Time.t option ; 
  subject : string ;
  html : string option ;
  text : string option ;
>

val get : CId.t -> Mail.I.t -> (#O.ctx, info option) Run.t

(** High-level aggregate statistics about sending an e-mail. *)
type stats = <
  prepared : int ;
  sent : int ;
  bounced : int ; 
  opened : int ; 
  clicked : int ; 
>

val stats : Mail.I.t -> (#O.ctx, stats) Run.t

(** The type of a link identifier. This is not an actual 11-character 
    identifier, but follows the [a-zA-Z0-9] convention anyway. *)
module Link : sig
  include Fmt.FMT 
  val to_string : t -> string
end

(** Follow a link. Marks that link as followed. *)
val follow : Link.t -> (#O.ctx, [ `NotFound of Link.t * Id.t
				| `Auth of Token.I.t * string
				| `Link of string
				| `Track ])  Run.t
