(* © 2014 RunOrg *)

open Std

let projection = Cqrs.Projection.make "sentmail" O.config

(* Individual e-mail status by (mid,cid) pair.
   =========================================== *)

module Status = type module [ `Unknown | `Scheduled | `Sent | `Failed ] 
module MidCid = type module (Mail.I.t * CId.t) 

let status = 

  let statusV, status = Cqrs.StatusView.make projection "status" 1 `Unknown
    (module MidCid : Fmt.FMT with type t = MidCid.t)
    (module Status : Fmt.FMT with type t = Status.t) in

  let () = Store.track statusV begin function 

    | `GroupWaveCreated  _ -> return ()
    | `BatchScheduled   ev -> 

      let mid = ev # mid in 
      List.M.iter (fun cid -> 
	Cqrs.StatusView.update status (mid,cid) (function 
	| `Unknown 
	| `Scheduled -> `Scheduled
	| `Sent      -> `Sent
	| `Failed    -> `Failed)) (ev # list) 

    | `Sent ev -> 
      
      Cqrs.StatusView.update status (ev # mid, ev # cid) (function 
      | `Unknown 
      | `Scheduled 
      | `Sent      -> `Sent
      | `Failed    -> `Failed)

    | `LinkFollowed   _ -> return () 
    | `SendingFailed ev -> 
  
      Cqrs.StatusView.update status (ev # mid, ev # cid) (function
      | `Unknown 
      | `Scheduled 
      | `Failed    -> `Failed
      | `Sent      -> `Sent)
    
  end in

  status
