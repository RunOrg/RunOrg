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

(* Individual e-mail info by (mid,cid) pair.
   =========================================== *)

module SentInfo = type module <
  sent   : Time.t ;
  input  : Json.t ; 
  from   : string ;
  to_    : string ; 
  link   : Link.Root.t ; 
>

module FailInfo = type module <
  failed : Time.t ;
  reason : [ `NoInfoAvailable 
	   | `NoSuchContact 
	   | `NoSuchSender    of CId.t 
	   | `SubjectError    of string * int * int 
	   | `TextError       of string * int * int 
	   | `HtmlError       of string * int * int 
	   | `Exception       of string 
	   ]
> 

module Info = type module <
  wid    : I.t ;
  pos    : int ; 
  status : [ `Scheduled 
	   | `Sent of SentInfo.t 
	   | `Failed of FailInfo.t ] ;
>

let info = 

  let infoV, info = Cqrs.MapView.make projection "info" 0
    (module MidCid : Fmt.FMT with type t = MidCid.t)
    (module Info : Fmt.FMT with type t = Info.t) in

  let () = Store.track infoV begin function 

    | `GroupWaveCreated  _ -> return ()
    | `BatchScheduled   ev -> 

      let mid = ev # mid in 
      List.M.iter 
	(fun (pos,cid) -> 
	  Cqrs.MapView.update info (mid,cid) (function 
	  | Some _ -> `Keep 
	  | None   -> `Put (Info.make ~wid:(ev # id) ~pos ~status:`Scheduled)))
	(List.mapi (fun i cid -> (i + ev # pos), cid) (ev # list)) 

    | `Sent ev -> 

      let! ctx = Run.context in 
      let  status = `Sent 
	(SentInfo.make 
	   ~sent:(ctx # time) ~input:(ev # input) ~link:(ev # link)
	   ~from:(ev # from) ~to_:(ev # to_)) in

      Cqrs.MapView.update info (ev # mid, ev # cid) (function 
      | None   -> `Keep 
      | Some i -> match i # status with 
	| `Sent    _ 
	| `Failed  _ -> `Keep
	| `Scheduled -> `Put (Info.make ~wid:(i # wid) ~pos:(i # pos) ~status)) 

    | `LinkFollowed   _ -> return () 
    | `SendingFailed ev -> 

      let! ctx = Run.context in 
      let  status = `Failed 
	(FailInfo.make 
	   ~failed:(ctx # time) ~reason:(ev # why)) in

      Cqrs.MapView.update info (ev # mid, ev # cid) (function 
      | None   -> `Keep 
      | Some i -> match i # status with 
	| `Sent    _ 
	| `Failed  _ -> `Keep
	| `Scheduled -> `Put (Info.make ~wid:(i # wid) ~pos:(i # pos) ~status)) 
    
  end in

  info

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
