(* © 2014 RunOrg *)

open Std

type info = <
  id       : I.t ; 
  count    : int option ;
  last     : Time.t option ; 
  subject  : String.Label.t option ; 
  access   : ChatAccess.Set.t ;
  audience : ChatAccess.Audience.t option ; 
>

val get : PId.t option -> I.t -> (#O.ctx, info option) Run.t

val all_as : ?limit:int -> ?offset:int -> PId.t option -> (#O.ctx, info list) Run.t

type post = <
  id     : PostI.t ;
  author : PId.t ;
  time   : Time.t ;
  body   : String.Rich.t ;
>

val list : 
  PId.t option -> 
  ?limit:int -> 
  ?offset:int -> 
  I.t -> (#O.ctx, [ `NeedRead of info 
		  | `NotFound of I.t 
		  | `OK of info * post list ]) Run.t

