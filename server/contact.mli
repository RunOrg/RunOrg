(* © 2014 RunOrg *)

open Std

(** Contacts represent people who can connect to the system and receive e-mails. *)

(** Create a new contact with the specified e-mail, and return its identifier. 
    If the e-mail already belongs to a contact, the identifier of that contact
    is returned instead. *)
val create : 
  ?fullname:String.Label.t -> 
  ?firstname:String.Label.t -> 
  ?lastname:String.Label.t -> 
  ?gender:[`F|`M] -> 
  String.Label.t -> (# O.ctx, CId.t * Cqrs.Clock.t) Run.t
  
(** A short profile for a contact. *)
type short = <
  id     : CId.t ;
  name   : String.Label.t ;
  pic    : string ; 
  gender : [`F|`M] option ; 
>

(** Return the short profile for a contact. *)
val get : CId.t -> (# O.ctx, short option) Run.t

(** Return the short profiles for all contacts. *)
val all : limit:int -> offset:int -> (# O.ctx, short list * int) Run.t

(** Search a contact by a prefix of a word in the fullname. *)
val search : ?limit:int -> string -> (#O.ctx, short list) Run.t

