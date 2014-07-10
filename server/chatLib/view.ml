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
    | `PublicChatCreated ev -> Cqrs.SetView.add exists [ev # id]
    | `ChatDeleted ev -> Cqrs.SetView.remove exists [ev # id] 
    | `PostCreated _ 
    | `PostDeleted _ -> return () 
  end in 

  exists

(* Chat feed contents
   ================== *)

module Item = type module <
  author : PId.t ;
  body   : String.Rich.t ;
>

let posts = 

  let postsV, posts = Cqrs.FeedMapView.make projection "posts" 0 
    (module I  : Fmt.FMT with type t = I.t)
    (module PostI : Fmt.FMT with type t = PostI.t)
    (module Item : Fmt.FMT with type t = Item.t) in

  let () = Store.track postsV begin function 

    | `PublicChatCreated _ 
    | `ChatCreated _ -> return () 

    | `ChatDeleted ev -> Cqrs.FeedMapView.delete posts (ev # id)

    | `PostDeleted ev -> 
      Cqrs.FeedMapView.update posts (ev # id) (ev # post)
	(function Some _ -> `Delete | None -> `Keep)

    | `PostCreated ev ->
      let! exists = Cqrs.SetView.exists exists (ev # id) in
      let! ctx = Run.context in 
      if not exists then return () else 
	Cqrs.FeedMapView.update posts (ev # id) (ev # post) (function 
	| None -> `Put (ctx # time, Item.make ~author:(ev # author) ~body:(ev # body))
	| Some _ -> `Keep)

  end in 

  posts

(* Chat information 
   ================ *)

module Info = type module <
  count   : int ;
  last    : Time.t ; 
  subject : String.Label.t option ; 
  people  : PId.t list ;
  groups  : GId.t list ;
  public  : bool ; 
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
    let! stats = Cqrs.FeedMapView.stats posts id in
    Cqrs.MapView.update info id (function None -> `Keep | Some info ->
      if info # count = stats # count then `Keep else `Put
	(Info.make 
	   ~subject:(info#subject) 
	   ~count:(stats#count) 
	   ~people:(info#people) 
	   ~groups:(info#groups)
	   ~public:(info#public)
	   ~last:(max (info#last) time)))
  in

  let () = Store.track infoV begin function 

    | `ChatCreated ev ->
      let! time = time () in 
      Cqrs.MapView.update info (ev # id) (function 
        | None -> `Put (Info.make ~subject:(ev#subject) ~count:0 ~people:(ev#people) ~groups:(ev#groups) 
			  ~public:false ~last:time)
	| Some _ -> `Keep)

    | `PublicChatCreated ev -> 
      let! time = time () in
      Cqrs.MapView.update info (ev # id) (function 
        | None -> `Put (Info.make ~subject:(ev#subject) ~count:0 ~people:[] ~groups:[] ~public:true
			  ~last:time)
	| Some _ -> `Keep)

    | `ChatDeleted ev -> 
      Cqrs.MapView.update info (ev # id) (function None -> `Keep | Some _ -> `Delete) 

    | `PostCreated ev -> recount (ev # id)
    | `PostDeleted ev -> recount (ev # id)

  end in 

  info

(* Chat access 
   =========== *)

module Accessor = type module 
  | Group of GId.t 
  | Person of PId.t
  | Public

let access = 

  let accessV, access = Cqrs.ManyToManyView.make projection "access" 1
    (module Accessor : Fmt.FMT with type t = Accessor.t)
    (module I : Fmt.FMT with type t = I.t) in

  let () = Store.track accessV begin function 

    | `ChatCreated ev ->

      let accessors = 
	List.map (fun cid -> Accessor.Person cid) (ev # people)
	@ List.map (fun gid -> Accessor.Group gid) (ev # groups) in
      Cqrs.ManyToManyView.add access accessors [ev # id]

    | `PublicChatCreated ev ->
      Cqrs.ManyToManyView.add access [Accessor.Public] [ev # id]

    | `ChatDeleted ev ->
      
      Cqrs.ManyToManyView.(delete (flip access) (ev # id))

    | `PostCreated _ 
    | `PostDeleted _ -> return ()

  end in
  
  access
