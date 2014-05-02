(* © 2014 RunOrg *)

open Std

type short = <
  id     : PId.t ;
  label  : String.Label.t ;
  pic    : string ; 
  gender : [`F|`M] option ; 
>

(** Create a [short] value from an identifier and an email. *)
val initial_short : PId.t -> String.Label.t -> short

val get : PId.t -> (# O.ctx, short option) Run.t

val all : PId.t option -> limit:int -> offset:int -> (# O.ctx, [ `NeedAccess of Id.t 
							       | `OK of short list * int ]) Run.t

val search : PId.t option -> ?limit:int -> string -> (#O.ctx, [ `NeedAccess of Id.t
							      | `OK of short list ]) Run.t

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

val full_forced : PId.t -> (#Cqrs.ctx, full option) Run.t

val full : PId.t option -> PId.t -> (#Cqrs.ctx, [ `NeedAccess of Id.t
						| `NotFound of PId.t
						| `OK of full ]) Run.t

val can_view_full : PId.t option -> PId.t -> (#Cqrs.ctx, bool) Run.t
