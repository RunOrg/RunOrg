(* © 2014 RunOrg *)

type info = <
  id : I.t ; 
  count : int ;
  contacts : CId.t list ;
  groups : Group.I.t list ;
>

val get : I.t -> (#O.ctx, info option) Run.t
