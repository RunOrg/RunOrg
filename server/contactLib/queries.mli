(* © 2014 RunOrg *)

open Std

type short = <
  id     : CId.t ;
  name   : String.Label.t ;
  pic    : string ; 
  gender : [`F|`M] option ; 
>

(** Create a [short] value from an identifier and an email. *)
val initial_short : CId.t -> String.Label.t -> short

val get : CId.t -> (# O.ctx, short option) Run.t

val all : limit:int -> offset:int -> (# O.ctx, short list * int) Run.t

val search : ?limit:int -> string -> (#O.ctx, short list) Run.t

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

val full : CId.t -> (#Cqrs.ctx, full option) Run.t
