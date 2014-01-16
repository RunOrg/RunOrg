(* © 2014 RunOrg *)

(** Contacts represent people who can connect to the system and receive e-mails. *)

(** Create a new contact with the specified e-mail, and return its identifier. 
    If the e-mail already belongs to a contact, the identifier of that contact
    is returned instead. *)
val create : 
  ?fullname:string -> 
  ?firstname:string -> 
  ?lastname:string -> 
  ?gender:[`F|`M] -> 
  string -> (# O.ctx, CId.t * Cqrs.Clock.t) Run.t
  
(** A short profile for a contact. *)
type short = <
  id     : CId.t ;
  name   : string ;
  pic    : string ; 
  gender : [`F|`M] option ; 
>

(** Return the short profile for a contact. *)
val get : CId.t -> (# O.ctx, short option) Run.t

