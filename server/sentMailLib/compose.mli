(* © 2014 RunOrg *)

(** Composing e-mails to be sent. *)

open Std

(** {2 Extracting raw data} *)

(** The raw data needed to send an e-mail. *)
type data = < 
  from    : < name : string option ; email : string > ;
  to_     : < name : string option ; email : string > ;
  input   : (string, Json.t) Map.t ;
  subject : Unturing.script ;
  text    : Unturing.script option ;
  html    : Unturing.script option ; 
> 

(** A failure that can occur while extracting raw data. *)
type failure = 
  [ `NoInfoAvailable 
  | `NoSuchRecipient 
  | `NoSuchSender    of PId.t 
  | `SubjectError    of string * int * int 
  | `TextError       of string * int * int 
  | `HtmlError       of string * int * int 
  | `Exception       of string 
  ]

(** Remove the links from the input map, as they can be re-created from the link root. 
    Call this function before saving input + link root to the database. [sent] below automatically
    re-composes links. *)
val remove_links : (string, Json.t) Map.t -> (string, Json.t) Map.t

(** Preview data for a (mail,contact) pair that has not been scheduled yet. 
    Works without accessing a wave OR a sent-mail. *)
val preview : Mail.info -> PId.t -> (#Cqrs.ctx, (data,failure) Std.result) Run.t

(** Data for a (mail,contact) pair that is scheduled but not yet sent. 
    This function is intended to be used by the sender, and therefore returns the 
    link root and wave ID (both must be saved). *)
val scheduled : Mail.I.t -> PId.t -> (#Cqrs.ctx, (I.t * Link.Root.t * data, failure) Std.result) Run.t

(** Data for a (mail,contact) pair that was already sent. Data is extracted from the 
    wave AND sent-mail objects. *)
val sent : I.t -> View.SentInfo.t -> (#Cqrs.ctx, (data,failure) Std.result) Run.t

(** {2 Rendering the e-mail} *)

(** A rendered e-mail. *)
type rendered = <
  from    : < name : string option ; email : string > ;
  to_     : < name : string option ; email : string > ;
  subject : string ;
  text    : string option ;
  html    : string option ;
>

(** Render an e-mail using input data. *)
val render : data -> rendered 
