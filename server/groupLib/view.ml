(* © 2014 RunOrg *)

open Std 

let projection = Cqrs.Projection.make "group" (fun () -> new O.ctx)

(* Group information 
   ================= *)

module Info = type module <
  label : string option 
>

let info = 
  
  let infoV, info = Cqrs.MapView.make projection "info" 0 
    (module I : Fmt.FMT with type t = I.t)
    (module Info : Fmt.FMT with type t = Info.t) in

  (* Create the admin group the first time it is mentioned. *)
  let ensure_admin id = 
    if I.to_string id = "admin" 
    then Cqrs.MapView.update info id (function None -> `Put (Info.make ~label:None) | _ -> `Keep)
    else return ()
  in

  let () = Store.track infoV begin function 

    | `Created ev -> 

      Cqrs.MapView.update info (ev # id) 
	(function 
	| None   -> `Put (Info.make ~label:(ev # label))
	| Some _ -> `Keep) 

    | `Deleted ev ->

      Cqrs.MapView.update info (ev # id) (fun _ -> `Delete)


    | `Added ev 
    | `Removed ev -> 

      List.M.iter ensure_admin (ev # groups)

  end in 

  info

(* Contacts in group 
   ================= *)

let contacts = 

  let contactsV, contacts = Cqrs.ManyToManyView.make projection "contacts" 0
    (module I : Fmt.FMT with type t = I.t)
    (module CId : Fmt.FMT with type t = CId.t) in

  let () = Store.track contactsV begin function 

    | `Created _ -> return () 
    | `Deleted ev -> 

      Cqrs.ManyToManyView.delete contacts (ev # id)

    | `Removed ev -> 
      
      Cqrs.ManyToManyView.remove contacts (ev # groups) (ev # contacts)

    | `Added ev ->

      Cqrs.ManyToManyView.add contacts (ev # groups) (ev # contacts) 

  end in 

  contacts
