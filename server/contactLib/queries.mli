(* © 2014 RunOrg *)

type short = <
  id     : CId.t ;
  name   : string ;
  pic    : string ; 
  gender : [`F|`M] option ; 
>

val get : CId.t -> (# O.ctx, short option) Run.t
