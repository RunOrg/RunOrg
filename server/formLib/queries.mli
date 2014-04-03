(* © 2014 RunOrg *)

open Std

type info = <
  id     : I.t ;
  owner  : Owner.t ;
  label  : String.Label.t option ; 
  fields : Field.t list ;
  custom : Json.t ;
  empty  : bool ; 
> 

val get : I.t -> (#O.ctx, info option) Run.t

val get_filled : 
  I.t ->
  FilledI.t ->
  (#O.ctx, (Field.I.t, Json.t) Map.t option) Run.t

