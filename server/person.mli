(* © 2014 RunOrg *)

open Std

(** People who can connect to the system and receive e-mails. *)

(** A function used to create people in the database. *)
type 'ctx creator = 
  ?name:String.Label.t -> 
  ?givenName:String.Label.t -> 
  ?familyName:String.Label.t -> 
  ?gender:[`F|`M] -> 
  String.Label.t -> ('ctx, PId.t * Cqrs.Clock.t) Run.t

(** Create a new profile without paying heed to any access restrictions. *)
val create_forced : #O.ctx creator

(** If allowed to import, return a person-creator function. *)
val import : PId.t option -> (#O.ctx as 'ctx, [ `OK of 'ctx creator | `NeedAccess of Id.t ]) Run.t
  
(** A short profile. *)
type short = <
  id     : PId.t ;
  label  : String.Label.t ;
  pic    : string ; 
  gender : [`F|`M] option ; 
>

(** Return the short profile for a person. *)
val get : PId.t -> (# O.ctx, short option) Run.t

(** Return the short profiles for all people. *)
val all : limit:int -> offset:int -> (# O.ctx, short list * int) Run.t

(** Search for a person by a prefix of a word in the fullname. *)
val search : ?limit:int -> string -> (#O.ctx, short list) Run.t

(** Attempt to log in with persona. Returns a token and the short profile for
    the authenticated token, or [None] if the authentication failed. May create a
    brand new contact. *)
val auth_persona : string -> (# O.ctx, ([`Person] Token.I.id * short * Cqrs.Clock.t) option) Run.t
  
(** A full profile for a person. *)
type full = <
  id         : PId.t ;
  label      : String.Label.t ;
  pic        : string ; 
  gender     : [`F|`M] option ; 
  email      : String.Label.t ; 
  name       : String.Label.t option ; 
  givenName  : String.Label.t option ;
  familyName : String.Label.t option ; 
>

(** Get the full profile of a person. *)
val full : PId.t -> (#Cqrs.ctx, full option) Run.t
