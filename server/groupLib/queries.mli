(* © 2014 RunOrg *)

val list : ?limit:int -> ?offset:int -> I.t -> (#O.ctx, CId.t list * int) Run.t

type info = <
  label : string option ; 
  count : int ;
>

val get : I.t -> (#O.ctx, info option) Run.t
