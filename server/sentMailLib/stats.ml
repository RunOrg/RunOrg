(* © 2014 RunOrg *)

open Std

module Summary = type module <
  scheduled : int ;
  sent      : int ;
  failed    : int ;
  opened    : int ;
  clicked   : int ;
>

let process mid =
  let! byStatus = Cqrs.StatusView.stats View.status mid in
  let! byOpenStatus = Cqrs.StatusView.stats View.openStatus mid in 
  return (object

    val scheduled = try Map.find `Scheduled byStatus with Not_found -> 0 
    val sent      = try Map.find `Sent      byStatus with Not_found -> 0
    val failed    = try Map.find `Failed    byStatus with Not_found -> 0 
    val opened    = try Map.find `Opened    byOpenStatus with Not_found -> 0 
    val clicked   = try Map.find `Clicked   byOpenStatus with Not_found -> 0

    method scheduled = scheduled
    method sent = sent
    method failed = failed
    method opened = opened + clicked
    method clicked = clicked

  end)

let compute = 
  Cqrs.HardStuffCache.make "sentmail.stats" 0 
    (module Mail.I : Fmt.FMT with type t = Mail.I.t) 
    (module Summary : Fmt.FMT with type t = Summary.t) 
    process 

