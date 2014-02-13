(* © 2014 RunOrg *)

open Std

val list : ?limit:int -> ?offset:int -> I.t -> (#O.ctx, CId.t list * int) Run.t

type info = <
  id    : I.t ;
  label : String.Label.t option ; 
  count : int ;
>

val get : I.t -> (#O.ctx, info option) Run.t

val all : limit:int -> offset:int -> (#O.ctx, info list * int) Run.t
