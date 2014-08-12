(* © 2014 RunOrg *)

open Std

let notFound id = `NotFound (!! "Chatroom '%s' does not exist." (Chat.I.to_string id)) 
let needAdmin id = `Forbidden (!! "You need 'admin' access to chatroom '%s'." (Chat.I.to_string id)) 
let needModerate id = `Forbidden (!! "You need 'moderate' access to chatroom '%s'." (Chat.I.to_string id)) 
let needPost id = `Forbidden (!! "You need 'post' access to chatroom '%s'." (Chat.I.to_string id)) 
let needRead id = `Forbidden (!! "You need 'read' access to chatroom '%s'." (Chat.I.to_string id)) 

let postNotFound id pid = 
  `NotFound (!! "Post %S does not exist in chatroom %S." (Chat.PostI.to_string pid) (Chat.I.to_string id)) 

(* Creating a chatroom
   =================== *)

module Create = Endpoint.Post(struct
    
  module Arg = type module unit
  module Post = type module <
    ?subject  : String.Label.t option ; 
    ?custom   : Json.t = Json.Null ; 
     audience : Chat.Access.Audience.t ; 
  >

  module Out = type module <
    id : Chat.I.t ;
    at : Cqrs.Clock.t ;
  >

  let path = "chat"

  let needAccess id = 
    `Forbidden (!! "Not allowed to create chatrooms in database %S." (Id.to_string id)) 

  let response req () post =

    let! result = Chat.create 
      (req # as_) 
      ?subject:(post # subject) 
      ~custom:(post # custom) 
      (post # audience) in 

    return (match result with
    | `NeedAccess id  -> needAccess id 
    | `OK    (id, at) -> `Accepted (Out.make ~id ~at))
	
end)

(* Updating a chatroom
   =================== *)

module Update = Endpoint.Put(struct
    
  module Arg = type module <
    id : Chat.I.t
  >

  module Put = type module <
    ?subject  : String.Label.t option ; 
    ?custom   : Json.t option ; 
    ?audience : Chat.Access.Audience.t option ; 
  >

  module Out = type module <
    at : Cqrs.Clock.t ;
  >

  let path = "chat/{id}"

  let response req arg put =

    let! result = Chat.update
      (req # as_) 
      ~subject:(Change.of_field "subject" (req # body) (put # subject))
      ~custom:(Change.of_option (put # custom))
      ~audience:(Change.of_option (put # audience))
      (arg # id) 
    in 

    return (match result with
    | `NotFound  id -> notFound id
    | `NeedAdmin id -> needAdmin id
    | `OK        at -> `Accepted (Out.make ~at))
	
end)

(* Deleting a chatroom
   =================== *)

module Delete = Endpoint.Delete(struct

  module Arg = type module < id : Chat.I.t >
  module Out = type module < at : Cqrs.Clock.t >

  let path = "chat/{id}"

  let response req arg = 
    let! result = Chat.delete (req # as_) (arg # id) in
    return (match result with 
    | `NotFound  id -> notFound id
    | `NeedAdmin id -> needAdmin id
    | `OK        at -> `Accepted (Out.make ~at))

end)

(* Adding a post to a chatroom
   =========================== *)

module CreatePost = Endpoint.Post(struct

  module Arg  = type module < id : Chat.I.t >
  module Post = type module <
    body   : String.Rich.t ;
   ?custom : Json.t = Json.Null ;
   ?reply  : Chat.PostI.t option ; 
  >

  module Out = type module <
    id : Chat.PostI.t ;
    at : Cqrs.Clock.t ;
  >

  let path = "chat/{id}/posts"

  let needAuthor = 
    `BadRequest "'as' parameter required to create a post."

  let postNotFound pid = 
    `NotFound (!! "The post '%s' you are replying to does not exist." (Chat.PostI.to_string pid))

  let response req arg post =
    match req # as_ with None -> return needAuthor | Some author -> 
      let! result = Chat.createPost (arg # id) author (post # body) (post # custom) (post # reply) in 
      return (match result with
      | `NotFound       id  -> notFound id
      | `PostNotFound (_,p) -> postNotFound p 
      | `NeedPost       id  -> needPost id
      | `OK        (id, at) -> `Accepted (Out.make ~id ~at))

end)

(* Deleting a post from a chatroom
   =============================== *)

module DeletePost = Endpoint.Delete(struct

  module Arg = type module < id : Chat.I.t ; post : Chat.PostI.t >
  module Out = type module < at : Cqrs.Clock.t >
      
  let path = "chat/{id}/posts/{post}"

  let response req arg = 
    let! result = Chat.deletePost (req # as_) (arg # id) (arg # post) in
    return (match result with 
    | `NotFound           id  -> notFound id
    | `PostNotFound (id, pid) -> postNotFound id pid
    | `NeedModerate       id  -> needModerate id 
    | `OK                 at  ->`Accepted (Out.make ~at))

end)

(* Obtaining chat information 
   ========================== *)

module ChatInfo = type module <
  id       : Chat.I.t ;
  subject  : String.Label.t option ;
  count    : int option ;
  last     : Time.t option ; 
  access   : Chat.Access.Set.t ; 
  audience : Chat.Access.Audience.t option ;  
  custom   : Json.t ; 
  track    : bool ;
>

module Get = Endpoint.Get(struct

  module Arg = type module < 
    id    : Chat.I.t ;
  >

  module Out = type module <
    info     : ChatInfo.t ;
  >

  let path = "chat/{id}"

  let response req arg = 
    let! info = Chat.get (req # as_) (arg # id) in 
    match info with None -> return (notFound (arg # id)) | Some info -> 
      return (`OK (Out.make ~info:(info :> ChatInfo.t)))

end)

module GetAllAs = Endpoint.Get(struct

  module Arg = type module unit
  module Out = type module <
    list   : ChatInfo.t list ;
  >

  let path = "chat"

  let response req _ = 
    let  limit  = Option.default 100 (req # limit) in
    let  offset = Option.default 0 (req # offset) in
    let! list = Chat.all_as ~limit ~offset (req # as_) in
    return (`OK (Out.make ~list:(list :> ChatInfo.t list)))

end)

(* Obtaining chat contents 
   ======================= *)

module Post = type module <
  id     : Chat.PostI.t ;
  author : PId.t ;
  time   : Time.t ; 
  body   : String.Rich.t ;
  track  : bool ; 
  tree   : < count : int ; top : t list > ;
>

let rec load_tree post = object
  method id     = post # id
  method author = post # author
  method time   = post # time
  method body   = post # body 
  method track  = post # track 
  method tree   = object
    method count = post # count
    method top   = List.map load_tree (post # sub) 
  end
end

let all_people list = 
  
  let rec aux set list = 
    List.fold_left 
      (fun set node -> 
	aux (Set.add (node # author) set) (node # tree # top))
      set list
  in

  Set.to_list (aux Set.empty list)

module Items = Endpoint.Get(struct

  module Arg = type module < 
    id    : Chat.I.t ; 
   ?under : Chat.PostI.t option ;   
  >

  module Out = type module <
    posts  : Post.t list ;
    people : PersonAPI.Short.t list ;
    count  : int 
  >

  let path = "chat/{id}/posts"

  let response req arg = 
    let! result = Chat.list 
      (req # as_) 
      ?limit:(req # limit) 
      ?offset:(req # offset) 
      ?parent:(arg # under) 
      (arg # id) in
    match result with 
    | `NeedRead info -> return (needRead (info # id))
    | `NotFound id -> return (notFound id)
    | `OK (count, posts) -> 
      let  posts  = List.map load_tree  posts in
      let  cids   = all_people posts in
      let! people = List.M.filter_map Person.get cids in
      return (`OK (Out.make ~posts ~people ~count))

end)
