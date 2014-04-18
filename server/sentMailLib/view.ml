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
      let! () = List.M.iter (fun cid -> 
	Cqrs.StatusView.update status (mid,cid) (function 
	| `Unknown 
	| `Scheduled -> `Scheduled
	| `Sent      -> `Sent
	| `Failed    -> `Failed)) (ev # list) in
      
      Common.ping_sender_service () 

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

(* Wave information 
   ================ *)

module Wave = type module <
  cid : CId.t option ;
  mid : Mail.I.t ;
  gid : GId.t ;
  from : CId.t ;
  subject : Unturing.t ;
  text : Unturing.t option ;
  html : Unturing.t option ;
  custom : Json.t ;
  urls : String.Url.t list ; 
  self : String.Url.t option ; 
>

let wave = 

  let waveV, wave = Cqrs.MapView.make projection "wave" 0
    (module I : Fmt.FMT with type t = I.t)
    (module Wave : Fmt.FMT with type t = Wave.t) in

  let () = Store.track waveV begin function 

    | `GroupWaveCreated ev ->

      let put = (ev :> Wave.t) in
      Cqrs.MapView.update wave (ev # id) (fun _ -> `Put put) 

    | `BatchScheduled    _  
    | `Sent              _ 
    | `LinkFollowed      _ 
    | `SendingFailed     _ -> return ()

  end in 

  wave
