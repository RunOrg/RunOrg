(* © 2014 RunOrg *)

open Std

let projection = Cqrs.Projection.make "sentmail" O.config

(* Individual e-mail status by (mid,cid) pair.
   =========================================== *)

module Status = type module [ `Scheduled | `Sent | `Failed ] 
module MidCid = type module (Mail.I.t * CId.t) 

let status = 

  let statusV, status = Cqrs.MapView.make projection "status" 0 
    (module MidCid : Fmt.FMT with type t = MidCid.t)
    (module Status : Fmt.FMT with type t = Status.t) in

  let () = Store.track statusV begin function 

    | `GroupWaveCreated  _ -> return ()
    | `BatchScheduled   ev -> 

      let mid = ev # mid in 
      List.M.iter (fun cid -> 
	Cqrs.MapView.update status (mid,cid) (function 
	| Some _ -> `Keep
	| None   -> `Put `Scheduled)) (ev # list) 

    | `Sent ev -> 
      
      Cqrs.MapView.update status (ev # mid, ev # cid) (function 
      | Some (`Sent|`Failed) -> `Keep 
      | _ -> `Put `Sent) 

    | `LinkFollowed   _ -> return () 
    | `SendingFailed ev -> 
  
      Cqrs.MapView.update status (ev # mid, ev # cid) (function
      | Some (`Sent|`Failed) -> `Keep
      | _ -> `Put `Failed)
    
  end in

  status
