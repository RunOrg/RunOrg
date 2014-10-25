(* © 2014 RunOrg *)

open Std

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
  PId.t option -> 
  Mail.I.t ->
  GId.t -> (#O.ctx, [ `NeedAccess of Id.t
		    | `NeedList of GId.t
		    | `NoSuchMail of Mail.I.t
		    | `NoSuchGroup of GId.t 
		    | `GroupEmpty of GId.t
		    | `OK of I.t * int * Cqrs.Clock.t ]) Run.t

(** Start sending a specific e-mail to a list of people. This will actually 
    cause the e-mails to be sent out. Creates a new wave and returns 
    its identifier. *)
val sendToPeople :
  PId.t option -> 
  Mail.I.t ->
  PId.t list -> (#O.ctx, [ `NeedAccess of Id.t
			 | `NoSuchMail of Mail.I.t
			 | `OK of I.t * int * Cqrs.Clock.t ]) Run.t
  
(** Current status of a sent e-mail. *)
module Status : Fmt.FMT with type t = 
  [ `Preview 
  | `Scheduled
  | `Sent ]

(** Failure to sent (or preview) an e-mail. *)
type failure = 
  [ `NoInfoAvailable 
  | `NoSuchRecipient 
  | `NoSuchSender    of PId.t 
  | `SubjectError    of string * int * int 
  | `TextError       of string * int * int 
  | `HtmlError       of string * int * int 
  | `Exception       of string 
  ]

(** Information about a mail sent to a specific person. *)
type info = <
  mail    : Mail.I.t ;
  to_     : PId.t ; 
  sent    : Time.t option ; 
  opened  : Time.t option ; 
  clicked : Time.t option ; 
  status  : Status.t ; 
  view    : <
    from    : < name : string option ; email : string > ;
    to_     : < name : string option ; email : string > ;
    subject : string ;
    html    : string option ;
    text    : string option ;
  > ; 
>

(** Returns a representation of a mail sent to a specific person. 
    This may be a preview (the mail is not sent yet, perhaps not
    even scheduled) or a view of what was sent. *)
val get : Mail.info -> PId.t -> (#O.ctx, (info,failure) Std.result) Run.t

(** High-level aggregate statistics about sending an e-mail. *)
type stats = <
  scheduled : int ;
  sent : int ;
  failed : int ; 
  opened : int ; 
  clicked : int ; 
>

val stats : PId.t option -> Mail.I.t -> (#O.ctx, [ `NoSuchMail of Mail.I.t
						 | `NeedAdmin  of Mail.I.t
						 | `OK of stats ]) Run.t

(** The type of a link identifier. This is not an actual 11-character 
    identifier, but follows the [a-zA-Z0-9] convention anyway. *)
module Link : sig
  include Fmt.FMT 
  val to_string : t -> string
end

(** Follow a link. Marks that link as followed. *)
val follow : Link.t -> IpAddress.t -> (#O.ctx, [ `NotFound of Link.t * Id.t
					       | `Auth of Token.I.t * String.Url.t
					       | `Link of String.Url.t
					       | `Track ]) Run.t

(** Try sending all currently scheduled mail. Call this function 
    at start-up to run the mailing service. *)
val run : unit -> 'ctx Run.effect
