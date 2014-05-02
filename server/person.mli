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
val all : PId.t option -> limit:int -> offset:int -> (# O.ctx, [ `NeedAccess of Id.t 
							       | `OK of short list * int ]) Run.t

(** Search for a person by a prefix of a word in the fullname. *)
val search : PId.t option -> ?limit:int -> string -> (#O.ctx, [ `NeedAccess of Id.t
							      | `OK of short list ]) Run.t

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
val full : PId.t option -> PId.t -> (#Cqrs.ctx, [ `NeedAccess of Id.t
						| `NotFound of PId.t
						| `OK of full ]) Run.t

(** Get the full profile of a person, without access level checks. Use
    internally, be cautious not to allow indirect access to data. *)
val full_forced : PId.t -> (#Cqrs.ctx, full option) Run.t

(** Can a contact view the full profile of another contact ? *)
val can_view_full : PId.t option -> PId.t -> (#Cqrs.ctx, bool) Run.t
