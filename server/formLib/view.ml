(* © 2014 RunOrg *)

open Std

let projection = Cqrs.Projection.make "form" O.config

(* Form information by identifier. 
   =============================== *)

module Info = type module <
  owner : Owner.t ;
  label : String.Label.t option ;
  fields : Field.t list ;
  custom : Json.t ;
  empty : bool ; 
  audience : FormAccess.Audience.t ; 
  clock : Cqrs.Clock.t ;
>

let info = 

  let infoV, info = Cqrs.MapView.make projection "info" 1 
    (module I : Fmt.FMT with type t = I.t)
    (module Info : Fmt.FMT with type t = Info.t) in

  let () = Store.track_full infoV begin fun arg ->

    let clock = arg # clock in 
    match arg # event with 

    | `Created ev -> 
      
      Cqrs.MapView.update info (ev # id) 
	(function 
	| None   -> `Put (Info.make 
			    ~owner:(ev # owner) ~label:(ev # label) 
			    ~fields:(ev # fields) ~custom:(ev # custom)
			    ~audience:(ev # audience) ~empty:true ~clock)
	| Some _ -> `Keep) 

    | `Updated ev -> 

      let if_empty = ev # fields <> None in
      Cqrs.MapView.update info (ev # id) 
	(function 
	| None -> `Keep
	| Some f when if_empty && not (f # empty) -> `Keep
	| Some f -> `Put (Info.make
			    ~owner:(Option.default (f # owner) (ev # owner))
			    ~label:(Option.default (f # label) (ev # label))
			    ~fields:(Option.default (f # fields) (ev # fields))
			    ~custom:(Option.default (f # custom) (ev # custom))
			    ~audience:(Option.default (f # audience) (ev # audience))
			    ~empty:(f # empty)
			    ~clock))

    | `Filled ev -> 

      Cqrs.MapView.update info (ev # id) 
	(function 
	| Some f -> `Put (Info.make 
			    ~owner:(f # owner) ~label:(f # label) 
			    ~fields:(f # fields) ~custom:(f # custom)
			    ~audience:(f # audience) ~empty:false ~clock) 
	| None -> `Keep) 


    | `Deleted ev ->

      Cqrs.MapView.update info (ev # id) (fun _ -> `Delete)
			    
  end in

  info

(* Finding forms by access level
   ============================= *)

let byAccess = 
  
  let byAccessV, byAccess = FormAccess.Map.make projection "byAccess" 0 
    ~only:[`Fill] (module I : Fmt.FMT with type t = I.t) in

  let () = Store.track byAccessV begin function

    | `Created ev -> 

      FormAccess.Map.update byAccess (ev # id) (ev # audience) 

    | `Updated ev -> 

      (match ev # audience with None -> return () | Some audience -> 
	FormAccess.Map.update byAccess (ev # id) audience)

    | `Filled _ -> return () 

    | `Deleted ev ->

       FormAccess.Map.remove byAccess (ev # id)
			  
  end in

  byAccess

(* Filled forms
   ============ *)

module FillInfo = type module <
  data : FillData.t
> 

let fillInfo = 
  
  let fillInfoV, fillInfo = Cqrs.FeedMapView.make projection "fillInfo" 1
    (module I : Fmt.FMT with type t = I.t)
    (module FilledI : Fmt.FMT with type t = FilledI.t)
    (module FillInfo : Fmt.FMT with type t = FillInfo.t) in

  let () = Store.track fillInfoV begin function 

    | `Created _ 
    | `Updated _ -> return ()  

    | `Filled ev -> 

      let! ctx = Run.context in
      Cqrs.FeedMapView.update fillInfo (ev # id) (ev # fid) 
	(function 
	| None       -> `Put (ctx # time, FillInfo.make ~data:(ev # data))
	| Some (_,t) -> `Put (ctx # time, FillInfo.make ~data:(Map.union (t # data) (ev # data))))  

    | `Deleted ev ->

       Cqrs.FeedMapView.delete fillInfo (ev # id)
	
  end in

  fillInfo
