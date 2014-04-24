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

val list : PId.t option -> limit:int -> offset:int -> (#O.ctx, info list) Run.t

type filled = <
  updated : Time.t ;
  owner   : FilledI.t ;
  data    : (Field.I.t, Json.t) Map.t ;
>

val get_filled : 
  PId.t option -> 
  I.t ->
  FilledI.t ->
  (#O.ctx, [ `NoSuchForm of I.t
	   | `NotFilled of I.t * FilledI.t 
	   | `NeedAdmin of I.t * FilledI.t
	   | `OK of (Field.I.t, Json.t) Map.t 
	   ]) Run.t

val list_filled :
  PId.t option ->
  ?limit:int ->
  ?offset:int ->
  I.t -> 
  (#O.ctx, [ `NoSuchForm of I.t
	   | `NeedAdmin of I.t
	   | `OK of < count : int ; list : filled list > 
	   ]) Run.t

val stats : 
  PId.t option ->
  I.t ->
  (#O.ctx, [ `NoSuchForm of I.t
	   | `NeedAdmin of I.t
	   | `OK of < fields : Stats.Summary.t ; count : int ; updated : Time.t option >
	   ]) Run.t

