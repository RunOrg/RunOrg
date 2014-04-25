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
  let! byStatus = Cqrs.StatusView.count View.status mid in
  return (object
    method scheduled = try Map.find `Scheduled byStatus with Not_found -> 0 
    method sent      = try Map.find `Sent      byStatus with Not_found -> 0
    method failed    = try Map.find `Failed    byStatus with Not_found -> 0 
    method opened    = 0
    method clicked   = 0
  end)

let compute = 
  Cqrs.HardStuffCache.make "sentmail.stats" 0 
    (module Mail.I : Fmt.FMT with type t = Mail.I.t) 
    (module Summary : Fmt.FMT with type t = Summary.t) 
    process 

