(* © 2014 RunOrg *)

open Std

type short = <
  id     : CId.t ;
  name   : String.Label.t ;
  pic    : string ; 
  gender : [`F|`M] option ; 
>

val get : CId.t -> (# O.ctx, short option) Run.t

val all : limit:int -> offset:int -> (# O.ctx, short list * int) Run.t
