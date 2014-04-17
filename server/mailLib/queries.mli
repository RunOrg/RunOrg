(* © 2014 RunOrg *)

open Std

type info = <
  id : I.t ;
  from : CId.t ;
  subject : String.Label.t ;
  text : string option ;
  html : String.Rich.t option ;
  audience : MailAccess.Audience.t ;
>

val get : I.t -> (#O.ctx, info option) Run.t
