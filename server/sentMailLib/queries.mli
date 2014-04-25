(* © 2014 RunOrg *)

type info = <
  mail : Mail.I.t ;
  to_  : PId.t ; 
  sent : Time.t option ; 
  opened  : Time.t option ; 
  subject : string ;
  html : string option ;
  text : string option ;
  status : Status.t ; 
>

val get : Mail.info -> PId.t -> (#O.ctx, (info,Compose.failure) Std.result) Run.t

type stats = <
  prepared : int ;
  sent : int ;
  bounced : int ; 
  opened : int ; 
  clicked : int ; 
>

val stats : Mail.I.t -> (#O.ctx, stats) Run.t

