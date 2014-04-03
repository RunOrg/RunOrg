(* © 2014 RunOrg *)

open Std

let projection = Cqrs.Projection.make "form" (fun () -> new O.ctx) 

(* Form information by identifier. *)

module Info = type module <
  owner : Owner.t ;
  label : String.Label.t option ;
  fields : Field.t list ;
  custom : Json.t ;
  empty : bool ; 
>

let info = 

  let infoV, info = Cqrs.MapView.make projection "info" 0 
    (module I : Fmt.FMT with type t = I.t)
    (module Info : Fmt.FMT with type t = Info.t) in

  let () = Store.track infoV begin function

    | `Created ev -> 

      Cqrs.MapView.update info (ev # id) 
	(function 
	| None   -> `Put (Info.make 
			    ~owner:(ev # owner) ~label:(ev # label) 
			    ~fields:(ev # fields) ~custom:(ev # custom)
			    ~empty:true)
	| Some _ -> `Keep) 

    | `Filled ev -> 

      Cqrs.MapView.update info (ev # id) 
	(function 
	| Some f when f # empty -> `Put (Info.make 
					   ~owner:(f # owner) ~label:(f # label) 
					   ~fields:(f # fields) ~custom:(f # custom)
					   ~empty:false) 
	| _ -> `Keep) 

  end in

  info
