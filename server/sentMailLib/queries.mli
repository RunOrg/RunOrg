(* © 2014 RunOrg *)

type info = <
  mail   : Mail.I.t ;
  to_    : PId.t ; 
  sent   : Time.t option ; 
  opened : Time.t option ; 
  status : Status.t ; 
  view   : <
    from    : string ;
    to_     : string ;
    subject : string ;
    html    : string option ;
    text    : string option ;
  > ; 
>

val get : Mail.info -> PId.t -> (#O.ctx, (info,Compose.failure) Std.result) Run.t

type stats = <
  scheduled : int ;
  sent : int ;
  failed : int ;
  opened : int ; 
  clicked : int ; 
>

val stats : Mail.I.t -> (#O.ctx, stats) Run.t

