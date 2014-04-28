(* © 2014 RunOrg *)

open Std

let projection = Cqrs.Projection.make "sentmail" O.config

(* Individual e-mail status by (mid,pid) pair.
   =========================================== *)

module Status = type module [ `Unknown | `Scheduled | `Sent | `Failed ] 
module MidPid = type module (Mail.I.t * PId.t) 

let status = 

  let statusV, status = Cqrs.StatusView.make projection "status" 2 `Unknown
    (module Mail.I : Fmt.FMT with type t = Mail.I.t)
    (module PId : Fmt.FMT with type t = PId.t)
    (module Status : Fmt.FMT with type t = Status.t) in

  let () = Store.track statusV begin function 

    | `GroupWaveCreated  _ -> return ()
    | `BatchScheduled   ev -> 

      let mid = ev # mid in 
      let! () = List.M.iter (fun pid -> 
	Cqrs.StatusView.update status mid pid (function 
	| `Unknown 
	| `Scheduled -> `Scheduled
	| `Sent      -> `Sent
	| `Failed    -> `Failed)) (ev # list) in
      
      Common.ping_sender_service () 

    | `Sent ev -> 
      
      Cqrs.StatusView.update status (ev # mid) (ev # pid) (function 
      | `Unknown 
      | `Scheduled 
      | `Sent      -> `Sent
      | `Failed    -> `Failed)

    | `LinkFollowed   _ -> return () 
    | `SendingFailed ev -> 
  
      Cqrs.StatusView.update status (ev # mid) (ev # pid) (function
      | `Unknown 
      | `Scheduled 
      | `Failed    -> `Failed
      | `Sent      -> `Sent)
    
  end in

  status

(* Individual e-mail info by (mid,pid) pair.
   =========================================== *)

module SentInfo = type module <
  sent   : Time.t ;
  input  : Json.t ; 
  from   : < name : string option ; email : string > ;
  to_    : < name : string option ; email : string > ; 
  link   : Link.Root.t ; 
>

module FailInfo = type module <
  failed : Time.t ;
  reason : [ `NoInfoAvailable 
	   | `NoSuchRecipient 
	   | `NoSuchSender    of PId.t 
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

  let infoV, info = Cqrs.MapView.make projection "info" 1
    (module MidPid : Fmt.FMT with type t = MidPid.t)
    (module Info : Fmt.FMT with type t = Info.t) in

  let () = Store.track infoV begin function 

    | `GroupWaveCreated  _ -> return ()
    | `BatchScheduled   ev -> 

      let mid = ev # mid in 
      List.M.iter 
	(fun (pos,pid) -> 
	  Cqrs.MapView.update info (mid,pid) (function 
	  | Some _ -> `Keep 
	  | None   -> `Put (Info.make ~wid:(ev # id) ~pos ~status:`Scheduled)))
	(List.mapi (fun i pid -> (i + ev # pos), pid) (ev # list)) 

    | `Sent ev -> 

      let! ctx = Run.context in 
      let  status = `Sent 
	(SentInfo.make 
	   ~sent:(ctx # time) ~input:(ev # input) ~link:(ev # link)
	   ~from:(ev # from) ~to_:(ev # to_)) in

      Cqrs.MapView.update info (ev # mid, ev # pid) (function 
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

      Cqrs.MapView.update info (ev # mid, ev # pid) (function 
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
  pid : PId.t option ;
  mid : Mail.I.t ;
  gid : GId.t ;
  from : PId.t ;
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

(* Clock information 
   ================= *)

let last = 

  let lastV, last = Cqrs.MapView.make projection "last" 0
    (module Mail.I : Fmt.FMT with type t = Mail.I.t)
    (module Cqrs.Clock : Fmt.FMT with type t = Cqrs.Clock.t) in

  let () = Store.track_full lastV begin fun arg ->
    let clock = arg # clock in
    let put e = Cqrs.MapView.update last (e # mid) (fun _ -> `Put clock) in
    match arg # event with 
    | `GroupWaveCreated  _  -> return () 
    | `BatchScheduled    ev -> put ev  
    | `Sent              ev -> put ev 
    | `LinkFollowed      ev -> put ev 
    | `SendingFailed     ev -> put ev

  end in 

  last
