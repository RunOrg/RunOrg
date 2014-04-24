(* © 2014 RunOrg *)

open Std

val list : ?limit:int -> ?offset:int -> GId.t -> (#O.ctx, PId.t list * int) Run.t

type info = <
  id    : GId.t ;
  label : String.Label.t option ; 
  count : int ;
>

val get : GId.t -> (#O.ctx, info option) Run.t

val all : limit:int -> offset:int -> (#O.ctx, info list * int) Run.t

val of_person : PId.t -> (#O.ctx, GId.t Set.t) Run.t
