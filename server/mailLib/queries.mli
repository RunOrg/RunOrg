(* © 2014 RunOrg *)

open Std

type info = <
  id       : I.t ;
  from     : PId.t ;
  subject  : Unturing.t ;
  text     : Unturing.t option ;
  html     : Unturing.t option ; 
  audience : MailAccess.Audience.t ;
  custom   : Json.t ;
  urls     : String.Url.t list ;
  self     : String.Url.t option ; 
>

val get : I.t -> (#O.ctx, info option) Run.t
