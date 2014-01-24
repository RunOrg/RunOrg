(* © 2014 RunOrg *)

type info = <
  id : I.t ; 
  count : int ;
  contacts : CId.t list ;
  groups : Group.I.t list ;
>

val get : I.t -> (#O.ctx, info option) Run.t

type item = <
  id : MI.t ;
  author : CId.t ;
  time : Time.t ;
  body : string ;
>

val list : ?limit:int -> ?offset:int -> I.t -> (#O.ctx, item list) Run.t
