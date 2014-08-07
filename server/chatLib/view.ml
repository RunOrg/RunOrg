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

  end in 

  posts

(* Chat information 
   ================ *)

module Info = type module <
  count    : int ;
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
	   ~audience:(info#audience)
	   ~custom:(info#custom)
	   ~last:(max (info#last) time)))
  in

  let () = Store.track infoV begin function 

    | `ChatCreated ev ->
      let! time = time () in 
      Cqrs.MapView.update info (ev # id) (function 
        | None -> `Put (Info.make ~subject:(ev#subject) ~count:0 ~audience:(ev#audience) ~last:time
			  ~custom:(ev#custom))
	| Some _ -> `Keep)

    | `ChatUpdated ev ->
      Cqrs.MapView.update info (ev # id) (function 
        | None -> `Keep 
        | Some old -> `Put (Info.make 
			      ~subject:(Change.apply (ev # subject) (old # subject))
			      ~audience:(Change.apply (ev # audience) (old # audience))
			      ~custom:(Change.apply (ev # custom) (old # custom))
			      ~last:(old # last)
			      ~count:(old # count)))

    | `ChatDeleted ev -> 
      Cqrs.MapView.update info (ev # id) (function None -> `Keep | Some _ -> `Delete) 

    | `PostCreated ev -> recount (ev # id)
    | `PostDeleted ev -> recount (ev # id)

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

    | `PostCreated _ 
    | `PostDeleted _ -> return ()

  end in
  
  byAccess
