(* © 2014 RunOrg *)

open Std

module Summary : Fmt.FMT with type t = <
  scheduled : int ;
  sent : int ;
  failed : int ;
  opened : int ;
  clicked : int ; 
>

val compute : (Mail.I.t, Summary.t) Cqrs.HardStuffCache.t 
