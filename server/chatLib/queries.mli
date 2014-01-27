(* © 2014 RunOrg *)

open Std

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
  body : String.Rich.t ;
>

val list : ?limit:int -> ?offset:int -> I.t -> (#O.ctx, item list) Run.t
