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

val all : limit:int -> offset:int -> (# O.ctx, short list * int) Run.t

val search : ?limit:int -> string -> (#O.ctx, short list) Run.t

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

val full : PId.t -> (#Cqrs.ctx, full option) Run.t
