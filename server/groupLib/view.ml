(* © 2014 RunOrg *)

open Std 

let projection = Cqrs.Projection.make "group" O.config

(* Group existence 
   =============== *)

let exists = 
  
  let existsV, exists = Cqrs.SetView.make projection "exists" 0 
    (module GId : Fmt.FMT with type t = GId.t) in

  (* Create the admin group the first time it is mentioned. *)
  let ensure_admin id = 
    if GId.is_admin id 
    then Cqrs.SetView.add exists [id] 
    else return ()
  in

  let () = Store.track existsV begin function 
    | `Created ev -> Cqrs.SetView.add exists [ev # id] 
    | `Deleted ev -> if GId.is_admin (ev # id) then return () else Cqrs.SetView.remove exists [ev # id]
    | `Added   ev 
    | `Removed ev -> List.M.iter ensure_admin (ev # groups)
  end in 

  exists

(* People in group 
   ================= *)

let people = 

  let peopleV, people = Cqrs.ManyToManyView.make projection "people" 2
    (module GId : Fmt.FMT with type t = GId.t)
    (module PId : Fmt.FMT with type t = PId.t) in

  let () = Store.track peopleV begin function 

    | `Created _ -> return () 
    | `Deleted ev -> 

      if GId.is_admin (ev # id) then return () else 
	Cqrs.ManyToManyView.delete people (ev # id)

    | `Removed ev -> 
      
      Cqrs.ManyToManyView.remove people (ev # groups) (ev # people)

    | `Added ev ->

      let! groups = List.M.filter (Cqrs.SetView.exists exists) (ev # groups) in
      if groups = [] then return () else 
	Cqrs.ManyToManyView.add people (ev # groups) (ev # people) 

  end in 

  people

(* Finding groups by access level
   ============================== *)

let byAccess = 
  
  let byAccessV, byAccess = GroupAccess.Map.make projection "byAccess" 0 
    ~only:[`View] (module GId : Fmt.FMT with type t = GId.t) in

  let () = Store.track byAccessV begin function 


    | `Created ev -> 

      GroupAccess.Map.update byAccess (ev # id) (ev # audience) 

    | `Deleted ev ->

      GroupAccess.Map.remove byAccess (ev # id) 

    | `Added    _ 
    | `Removed  _ -> return ()

  end in 

  byAccess

(* Group information 
   ================= *)

module Info = type module <
  label    : String.Label.t option ;
  count    : int ; 
  audience : GroupAccess.Audience.t ; 
>

let info = 
  
  let infoV, info = Cqrs.MapView.make projection "info" 1
    (module GId : Fmt.FMT with type t = GId.t)
    (module Info : Fmt.FMT with type t = Info.t) in

  (* Create the admin group the first time it is mentioned. *)
  let count gid = 
    let! count = Cqrs.ManyToManyView.count people gid in 
    Cqrs.MapView.update info gid (function
      | None -> 
	if GId.is_admin gid then `Put (Info.make ~label:None ~count ~audience:Map.empty) else `Keep
      | Some g -> 
	if g # count = count then `Keep else `Put (Info.make ~label:(g#label) ~audience:(g#audience) ~count))
  in

  let () = Store.track infoV begin function 

    | `Created ev -> 

      Cqrs.MapView.update info (ev # id) 
	(function 
	| None   -> `Put (Info.make ~label:(ev # label) ~count:0 ~audience:(ev # audience))
	| Some _ -> `Keep) 

    | `Deleted ev ->

      Cqrs.MapView.update info (ev # id) (fun _ -> `Delete)

    | `Added ev 
    | `Removed ev -> 

      List.M.iter count (ev # groups)

  end in 

  info
