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

(** Attempt to log in with persona. Returns a token and the short profile for
    the authenticated token, or [None] if the authentication failed. May create a
    brand new contact. *)
val auth_persona : string -> (# O.ctx, ([`Contact] Token.I.id * short * Cqrs.Clock.t) option) Run.t
  
(** A full profile for a contact. *)
type full = <
  id        : CId.t ;
  name      : String.Label.t ;
  pic       : string ; 
  gender    : [`F|`M] option ; 
  email     : String.Label.t ; 
  fullname  : String.Label.t option ; 
  firstname : String.Label.t option ;
  lastname  : String.Label.t option ; 
>

(** Get the full profile of a contact. *)
val full : CId.t -> (#O.ctx, full option) Run.t
