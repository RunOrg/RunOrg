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

let get cid mid = 
  assert false

type stats = <
  prepared : int ;
  sent : int ;
  bounced : int ; 
  opened : int ; 
  clicked : int ; 
>

let stats mid = 
  assert false



