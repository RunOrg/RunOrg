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
  audience : FormAccess.Audience.t ; 
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
			    ~audience:(ev # audience) ~empty:true)
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
			    ~empty:(f # empty)))

    | `Filled ev -> 

      Cqrs.MapView.update info (ev # id) 
	(function 
	| Some f when f # empty -> `Put (Info.make 
					   ~owner:(f # owner) ~label:(f # label) 
					   ~fields:(f # fields) ~custom:(f # custom)
					   ~audience:(f # audience) ~empty:false) 
	| _ -> `Keep) 

  end in

  info
