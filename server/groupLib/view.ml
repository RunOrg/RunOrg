(* © 2014 RunOrg *)

open Std 

let projection = Cqrs.Projection.make "group" (fun () -> new O.ctx)

(* Group existence 
   =============== *)

let exists = 
  
  let existsV, exists = Cqrs.SetView.make projection "exists" 0 
    (module I : Fmt.FMT with type t = I.t) in

  (* Create the admin group the first time it is mentioned. *)
  let ensure_admin id = 
    if I.is_admin id 
    then Cqrs.SetView.add exists [id] 
    else return ()
  in

  let () = Store.track existsV begin function 
    | `Created ev -> Cqrs.SetView.add exists [ev # id] 
    | `Deleted ev -> if I.is_admin (ev # id) then return () else Cqrs.SetView.remove exists [ev # id]
    | `Added   ev 
    | `Removed ev -> List.M.iter ensure_admin (ev # groups)
  end in 

  exists

(* Contacts in group 
   ================= *)

let contacts = 

  let contactsV, contacts = Cqrs.ManyToManyView.make projection "contacts" 2
    (module I : Fmt.FMT with type t = I.t)
    (module CId : Fmt.FMT with type t = CId.t) in

  let () = Store.track contactsV begin function 

    | `Created _ -> return () 
    | `Deleted ev -> 

      if I.is_admin (ev # id) then return () else 
	Cqrs.ManyToManyView.delete contacts (ev # id)

    | `Removed ev -> 
      
      Cqrs.ManyToManyView.remove contacts (ev # groups) (ev # contacts)

    | `Added ev ->

      let! groups = List.M.filter (Cqrs.SetView.exists exists) (ev # groups) in
      if groups = [] then return () else 
	Cqrs.ManyToManyView.add contacts (ev # groups) (ev # contacts) 

  end in 

  contacts

(* Group information 
   ================= *)

module Info = type module <
  label : string option ;
  count : int ; 
>

let info = 
  
  let infoV, info = Cqrs.MapView.make projection "info" 1
    (module I : Fmt.FMT with type t = I.t)
    (module Info : Fmt.FMT with type t = Info.t) in

  (* Create the admin group the first time it is mentioned. *)
  let count gid = 
    let! count = Cqrs.ManyToManyView.count contacts gid in 
    Cqrs.MapView.update info gid (function
      | None -> if I.is_admin gid then `Put (Info.make ~label:None ~count:0) else `Keep
      | Some g -> if g # count = count then `Keep else `Put (Info.make ~label:(g#label) ~count))
  in

  let () = Store.track infoV begin function 

    | `Created ev -> 

      Cqrs.MapView.update info (ev # id) 
	(function 
	| None   -> `Put (Info.make ~label:(ev # label) ~count:0)
	| Some _ -> `Keep) 

    | `Deleted ev ->

      Cqrs.MapView.update info (ev # id) (fun _ -> `Delete)

    | `Added ev 
    | `Removed ev -> 

      List.M.iter count (ev # groups)

  end in 

  info
