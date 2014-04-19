(* © 2014 RunOrg *)

type info = <
  mail : Mail.I.t ;
  to_  : CId.t ; 
  sent : Time.t option ; 
  opened  : Time.t option ; 
  subject : string ;
  html : string option ;
  text : string option ;
>

val get : CId.t -> Mail.I.t -> (#O.ctx, info option) Run.t

type stats = <
  prepared : int ;
  sent : int ;
  bounced : int ; 
  opened : int ; 
  clicked : int ; 
>

val stats : Mail.I.t -> (#O.ctx, stats) Run.t
