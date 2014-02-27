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

(* Chat feed contents
   ================== *)

module Item = type module <
  author : CId.t ;
  body   : String.Rich.t ;
>

let items = 

  let itemsV, items = Cqrs.FeedMapView.make projection "items" 0 
    (module I  : Fmt.FMT with type t = I.t)
    (module MI : Fmt.FMT with type t = MI.t)
    (module Item : Fmt.FMT with type t = Item.t) in

  let () = Store.track itemsV begin function 

    | `PrivateMessageCreated _ 
    | `ChatCreated _ -> return () 

    | `ChatDeleted ev -> Cqrs.FeedMapView.delete items (ev # id)

    | `ItemDeleted ev -> 
      Cqrs.FeedMapView.update items (ev # id) (ev # item)
	(function Some _ -> `Delete | None -> `Keep)

    | `ItemPosted ev ->
      let! exists = Cqrs.SetView.exists exists (ev # id) in
      let! ctx = Run.context in 
      if not exists then return () else 
	Cqrs.FeedMapView.update items (ev # id) (ev # item) (function 
	| None -> `Put (ctx # time, Item.make ~author:(ev # author) ~body:(ev # body))
	| Some _ -> `Keep)

  end in 

  items

(* Chat information 
   ================ *)

module Info = type module <
  count : int ;
 ?subject : String.Label.t option ; 
  contacts : CId.t list ;
  groups : Group.I.t list ;
>

let info = 

  let infoV, info = Cqrs.MapView.make projection "info" 0
    (module I : Fmt.FMT with type t = I.t) 
    (module Info : Fmt.FMT with type t = Info.t) in

  let recount id = 
    let! stats = Cqrs.FeedMapView.stats items id in
    Cqrs.MapView.update info id (function None -> `Keep | Some info ->
      if info # count = stats # count then `Keep else `Put
	(Info.make 
	   ~subject:(info#subject) 
	   ~count:(stats#count) 
	   ~contacts:(info#contacts) 
	   ~groups:(info#groups)))
  in

  let () = Store.track infoV begin function 

    | `PrivateMessageCreated ev -> 
      let ida, idb = ev # who in 
      Cqrs.MapView.update info (ev # id) (function 
        | None -> `Put (Info.make ~subject:None ~count:0 ~contacts:[ida;idb] ~groups:[])
	| Some _ -> `Keep)

    | `ChatCreated ev ->
      Cqrs.MapView.update info (ev # id) (function 
        | None -> `Put (Info.make ~subject:(ev#subject) ~count:0 ~contacts:(ev#contacts) ~groups:(ev#groups))
	| Some _ -> `Keep)

    | `ChatDeleted ev -> 
      Cqrs.MapView.update info (ev # id) (function None -> `Keep | Some _ -> `Delete) 

    | `ItemPosted ev -> recount (ev # id)
    | `ItemDeleted ev -> recount (ev # id)

  end in 

  info

(* Chat access 
   =========== *)

module Accessor = type module 
  | Group of Group.I.t 
  | Contact of CId.t

let access = 

  let accessV, access = Cqrs.ManyToManyView.make projection "access" 0 
    (module Accessor : Fmt.FMT with type t = Accessor.t)
    (module I : Fmt.FMT with type t = I.t) in

  let () = Store.track accessV begin function 

    | `PrivateMessageCreated ev ->

      let ida, idb = ev # who in 
      Cqrs.ManyToManyView.add access Accessor.([ Contact ida ; Contact idb ]) [ev # id]

    | `ChatCreated ev ->

      let accessors = 
	List.map (fun cid -> Accessor.Contact cid) (ev # contacts)
	@ List.map (fun gid -> Accessor.Group gid) (ev # groups) in
      Cqrs.ManyToManyView.add access accessors [ev # id]

    | `ChatDeleted ev ->
      
      Cqrs.ManyToManyView.(delete (flip access) (ev # id))

    | `ItemPosted _ 
    | `ItemDeleted _ -> return ()

  end in
  
  access
