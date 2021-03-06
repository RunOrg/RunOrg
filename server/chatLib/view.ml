(* © 2014 RunOrg *)

open Std

let projection = Cqrs.Projection.make "chat" O.config

(* Chat existence 
   ============== *)

let exists = 
  
  let existsV, exists = Cqrs.SetView.make projection "exists" 0 
    (module I : Fmt.FMT with type t = I.t) in

  let () = Store.track existsV begin function 
    | `ChatCreated ev -> Cqrs.SetView.add exists [ev # id]
    | `ChatDeleted ev -> Cqrs.SetView.remove exists [ev # id] 
    | `ChatUpdated _
    | `TrackEnabled _
    | `TrackDisabled _
    | `MarkedAsRead _
    | `TrackerGarbageCollected _ 
    | `PostCreated _ 
    | `PostDeleted _ -> return () 
  end in 

  exists

(* Chat feed contents
   ================== *)

module Item = type module <
  author : PId.t ;
  body   : String.Rich.t ;
  custom : Json.t ; 
>

let posts = 

  let postsV, posts = Cqrs.TreeMapView.make projection "posts" 1 
    (module I : Fmt.FMT with type t = I.t)
    (module PostI : Fmt.FMT with type t = PostI.t)
    (module Item : Fmt.FMT with type t = Item.t) in

  let () = Store.track postsV begin function 

    | `ChatCreated _  
    | `ChatUpdated _ -> return ()

    | `ChatDeleted ev -> 

      Cqrs.TreeMapView.delete posts (ev # id)

    | `PostDeleted ev -> 

      Cqrs.TreeMapView.update posts (ev # id) (ev # post)
	(function Some _ -> `Delete | None -> `Keep)

    | `PostCreated ev ->

      let! chat_exists = Cqrs.SetView.exists exists (ev # id) in
      let! parent_exists = match ev # parent with 
	| None -> return true
	| Some p -> Cqrs.TreeMapView.exists posts (ev # id) p in

      let! ctx = Run.context in 
      if not chat_exists || not parent_exists then return () else 
	Cqrs.TreeMapView.update posts (ev # id) (ev # post) (function 
	| None -> `Put (ctx # time, ev # parent, 
			Item.make ~author:(ev # author) ~body:(ev # body) ~custom: (ev # custom))
	| Some _ -> `Keep)

    | `TrackEnabled _
    | `TrackDisabled _
    | `TrackerGarbageCollected _
    | `MarkedAsRead _ -> return () 

  end in 

  posts

(* Chat information 
   ================ *)

module Info = type module <
  count    : int ;
  root     : int ; 
  last     : Time.t ; 
  subject  : String.Label.t option ; 
  audience : ChatAccess.Audience.t ; 
  custom   : Json.t ; 
>

let info = 

  let infoV, info = Cqrs.MapView.make projection "info" 1
    (module I : Fmt.FMT with type t = I.t) 
    (module Info : Fmt.FMT with type t = Info.t) in

  let time () = 
    let! ctx = Run.context in 
    return (ctx # time)  
  in

  let recount id = 
    let! time = time () in
    let! stats = Cqrs.TreeMapView.stats posts id in
    Cqrs.MapView.update info id (function None -> `Keep | Some info ->
      if info # count = stats # count then `Keep else `Put
	(Info.make 
	   ~subject:(info#subject) 
	   ~count:(stats#count) 
	   ~root:(stats#root)
	   ~audience:(info#audience)
	   ~custom:(info#custom)
	   ~last:(max (info#last) time)))
  in

  let () = Store.track infoV begin function 

    | `ChatCreated ev ->
      let! time = time () in 
      Cqrs.MapView.update info (ev # id) (function 
        | None -> `Put (Info.make ~subject:(ev#subject) ~count:0 ~root:0
			  ~audience:(ev#audience) ~last:time ~custom:(ev#custom))
	| Some _ -> `Keep)

    | `ChatUpdated ev ->
      Cqrs.MapView.update info (ev # id) (function 
        | None -> `Keep 
        | Some old -> `Put (Info.make 
			      ~subject:(Change.apply (ev # subject) (old # subject))
			      ~audience:(Change.apply (ev # audience) (old # audience))
			      ~custom:(Change.apply (ev # custom) (old # custom))
			      ~last:(old # last)
			      ~count:(old # count)
			      ~root:(old # root)))

    | `ChatDeleted ev -> 
      Cqrs.MapView.update info (ev # id) (function None -> `Keep | Some _ -> `Delete) 

    | `PostCreated ev -> recount (ev # id)
    | `PostDeleted ev -> recount (ev # id)

    | `TrackEnabled _
    | `TrackDisabled _
    | `MarkedAsRead _
    | `TrackerGarbageCollected _ -> return ()

  end in 

  info

(* Chat access 
   =========== *)

let byAccess = 

  let byAccessV, byAccess = ChatAccess.Map.make projection "byAccess" 0 
    ~only:[`View] (module I : Fmt.FMT with type t = I.t) in 

  let () = Store.track byAccessV begin function 

    | `ChatCreated ev ->

      ChatAccess.Map.update byAccess (ev # id) (ev # audience)

    | `ChatUpdated ev ->
      
      (match ev # audience with 
      | `Keep  -> return ()
      | `Set a -> ChatAccess.Map.update byAccess (ev # id) a)

    | `ChatDeleted ev ->
      
      ChatAccess.Map.remove byAccess (ev # id)

    | `TrackEnabled _
    | `TrackDisabled _
    | `MarkedAsRead _
    | `TrackerGarbageCollected _ 
    | `PostCreated _ 
    | `PostDeleted _ -> return ()

  end in
  
  byAccess

(* Tracking 
   ======== *)

module PostOpt = type module (PostI.t option) 

let trackers =
 
  let trackersV, trackers = Cqrs.TripleSetView.make projection "trackers" 0 
    (module I : Fmt.FMT with type t = I.t)
    (module PostOpt : Fmt.FMT with type t = PostOpt.t)
    (module PId : Fmt.FMT with type t = PId.t)
  in 

  let () = Store.track trackersV begin function

    | `ChatCreated _
    | `ChatUpdated _ 
    | `PostCreated _ 
    | `MarkedAsRead _ -> return () 

    | `ChatDeleted ev -> Cqrs.TripleSetView.delete trackers (ev # id)
    | `PostDeleted ev -> Cqrs.TripleSetView.delete2 trackers (ev # id) (Some (ev # post))

    | `TrackEnabled ev -> Cqrs.TripleSetView.add trackers (ev # id) (ev # post) [ev # pid]
    | `TrackDisabled ev -> Cqrs.TripleSetView.remove trackers (ev # id) (ev # post) [ev # pid]

    | `TrackerGarbageCollected ev -> 

      Cqrs.TripleSetView.(delete2 (flipBC trackers) (ev # id) (ev # pid))
      
  end in
  
  trackers


let unread = 
  
  let unreadV, unread = Cqrs.TripleSetView.make projection "unread" 0
    (module I : Fmt.FMT with type t = I.t)
    (module PostI : Fmt.FMT with type t = PostI.t) 
    (module PId : Fmt.FMT with type t = PId.t)
  in

  let () = Store.track unreadV begin function 

    | `ChatCreated _ 
    | `ChatUpdated _ -> return () 

    | `PostCreated ev -> 

      let! people = Cqrs.TripleSetView.all2 trackers (ev # id) (ev # parent) in
      Cqrs.TripleSetView.add unread (ev # id) (ev # post) people
      
    | `ChatDeleted  ev -> Cqrs.TripleSetView.delete unread (ev # id) 
    | `PostDeleted  ev -> Cqrs.TripleSetView.delete2 unread (ev # id) (ev # post)
    | `MarkedAsRead ev -> Cqrs.TripleSetView.(remove (flipBC unread) (ev # id) (ev # pid) (ev # posts))
    | `TrackDisabled ev -> return ()
    | `TrackEnabled  ev -> return ()
    | `TrackerGarbageCollected ev -> Cqrs.TripleSetView.(delete2 (flipBC unread) (ev # id) (ev # pid))

  end in 

  unread 
