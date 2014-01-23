(* © 2014 RunOrg *)

open Std

let projection = Cqrs.Projection.make "chat" (fun () -> new O.ctx)

(* Chat existence 
   ============== *)

let exists = 
  
  let existsV, exists = Cqrs.SetView.make projection "exists" 0 
    (module I : Fmt.FMT with type t = I.t) in

  let () = Store.track existsV begin function 
    | `PrivateMessageCreated ev -> Cqrs.SetView.add exists [ev # id]
    | `ChatCreated ev -> Cqrs.SetView.add exists [ev # id]
    | `ChatDeleted ev -> Cqrs.SetView.remove exists [ev # id] 
    | `ItemPosted _ 
    | `ItemDeleted _ -> return () 
  end in 

  exists

(* Chat information 
   ================ *)

module Info = type module <
  count : int ;
  contacts : CId.t list ;
  groups : Group.I.t list ;
>

let info = 

  let infoV, info = Cqrs.MapView.make projection "exists" 0
    (module I : Fmt.FMT with type t = I.t) 
    (module Info : Fmt.FMT with type t = Info.t) in

  let () = Store.track infoV begin function 
    | `PrivateMessageCreated ev -> 
      let ida, idb = ev # who in 
      Cqrs.MapView.update info (ev # id) (function 
        | None -> `Put (Info.make ~count:0 ~contacts:[ida;idb] ~groups:[])
	| Some _ -> `Keep)
    | `ChatCreated ev ->
      Cqrs.MapView.update info (ev # id) (function 
        | None -> `Put (Info.make ~count:0 ~contacts:(ev#contacts) ~groups:(ev#groups))
	| Some _ -> `Keep)
    | `ChatDeleted ev -> 
      Cqrs.MapView.update info (ev # id) (function None -> `Keep | Some _ -> `Delete) 
    | `ItemPosted _ 
    | `ItemDeleted _ -> return ()
  end in 

  info
