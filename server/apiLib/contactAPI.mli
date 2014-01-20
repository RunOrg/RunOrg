(* © 2014 RunOrg *)

module Short : Fmt.FMT with type t = <
  id     : CId.t ;
  name   : string ; 
  gender : [`F|`M] option ;
  pic    : string ; 
>
