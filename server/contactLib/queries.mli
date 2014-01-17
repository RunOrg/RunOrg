(* © 2014 RunOrg *)

type short = <
  id     : CId.t ;
  name   : string ;
  pic    : string ; 
  gender : [`F|`M] option ; 
>

val get : CId.t -> (# O.ctx, short option) Run.t

val all : limit:int -> offset:int -> (# O.ctx, short list * int) Run.t
