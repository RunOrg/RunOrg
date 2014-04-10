(* © 2014 RunOrg *)

open Std

type info =  <
  id       : I.t ;
  owner    : Owner.t ;
  label    : String.Label.t option ; 
  fields   : Field.t list ;
  custom   : Json.t ;
  audience : FormAccess.Audience.t ;
  empty    : bool ; 
> 

val get : I.t -> (#O.ctx, info option) Run.t

val list : CId.t option -> limit:int -> offset:int -> (#O.ctx, info list) Run.t

val get_filled : 
  CId.t option -> 
  I.t ->
  FilledI.t ->
  (#O.ctx, [ `NoSuchForm of I.t
	   | `NotFilled of I.t * FilledI.t 
	   | `NeedAdmin of I.t * FilledI.t
	   | `OK of (Field.I.t, Json.t) Map.t 
	   ]) Run.t

