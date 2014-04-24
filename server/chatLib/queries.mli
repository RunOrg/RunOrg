(* © 2014 RunOrg *)

open Std

type info = <
  id      : I.t ; 
  count   : int ;
  last    : Time.t ; 
  people  : PId.t list ;
  groups  : GId.t list ;
  subject : String.Label.t option ; 
  public  : bool ;
>

val get : I.t -> (#O.ctx, info option) Run.t

type item = <
  id     : MI.t ;
  author : PId.t ;
  time   : Time.t ;
  body   : String.Rich.t ;
>

val list : ?limit:int -> ?offset:int -> I.t -> (#O.ctx, item list) Run.t

val all_as : ?limit:int -> ?offset:int -> PId.t option -> (#O.ctx, info list) Run.t
