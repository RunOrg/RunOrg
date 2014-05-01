(* © 2014 RunOrg *)

open Std

val list : PId.t option -> ?limit:int -> ?offset:int -> GId.t 
  -> (#O.ctx, [ `OK of PId.t list * int
	      | `NotFound of GId.t 
	      | `NeedList of GId.t ]) Run.t

val list_force : ?limit:int -> ?offset:int -> GId.t -> (#O.ctx, PId.t list) Run.t

type info = <
  id     : GId.t ;
  label  : String.Label.t option ; 
  access : GroupAccess.Set.t ; 
  count  : int option ;
>

val get : PId.t option -> GId.t -> (#O.ctx, info option) Run.t

val all : PId.t option -> limit:int -> offset:int -> (#O.ctx, info list) Run.t

val of_person : PId.t -> (#O.ctx, GId.t Set.t) Run.t
