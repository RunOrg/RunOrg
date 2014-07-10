(* © 2014 RunOrg *)

open Std

module Create = Endpoint.Post(struct
    
  module Arg = type module unit
  module Post = type module <
    ?subject  : String.Label.t option ; 
    ?people   : PId.t list     = [] ;
    ?groups   : GId.t list     = [] ;
    ?public   : bool           = false ; 
  >

  module Out = type module <
    id : Chat.I.t ;
    at : Cqrs.Clock.t ;
  >

  let path = "chat"

  let create_public post = 
    if post # groups <> [] then
      return (`BadRequest "A public chatroom may not involve groups")
    else if post # people <> [] then
      return (`BadRequest "A private chatroom may not involve people")
    else 
      let! id, at = Chat.createPublic (post # subject) in
      return (`Accepted (Out.make ~id ~at))

  let create post = 
    if post # people = [] && post # groups = [] then
      return (`BadRequest "Please provide at least one person or group")
    else
      let! id, at = Chat.create ?subject:(post # subject) (post # people) (post # groups) in 
      return (`Accepted (Out.make ~id ~at))

  let response req () post =
    if post # public then create_public post 
    else create post 
	
end)

module Delete = Endpoint.Delete(struct

  module Arg = type module < id : Chat.I.t >
  module Out = type module < at : Cqrs.Clock.t >

  let path = "chat/{id}"

  let response req arg = 
    let! at = Chat.delete (arg # id) in
    return (`Accepted (Out.make ~at))

end)

module Post = Endpoint.Post(struct

  module Arg  = type module < id : Chat.I.t >
  module Post = type module <
    author : PId.t ;
    body : String.Rich.t ;
  >

  module Out = type module <
    id : Chat.MI.t ;
    at : Cqrs.Clock.t ;
  >

  let path = "chat/{id}"

  let response req arg post = 
    let! id, at = Chat.post (arg # id) (post # author) (post # body) in 
    return (`Accepted (Out.make ~id ~at))

end)

module DeleteItem = Endpoint.Delete(struct

  module Arg = type module < id : Chat.I.t ; item : Chat.MI.t >
  module Out = type module < at : Cqrs.Clock.t >
      
  let path = "chat/{id}/items/{item}"

  let response req arg = 
    let! at = Chat.deleteItem (arg # id) (arg # item) in
    return (`Accepted (Out.make ~at))

end)

(* Obtaining chat information 
   ========================== *)

let not_found id = 
  `NotFound (!! "Chat '%s' does not exist" (Chat.I.to_string id))

module ChatInfo = type module <
  id      : Chat.I.t ;
  subject : String.Label.t option ;
  people  : PId.t list ;
  groups  : GId.t list ;
  count   : int ;
  last    : Time.t ; 
  public  : bool ; 
>

module Get = Endpoint.Get(struct

  module Arg = type module < id : Chat.I.t >
  module Out = type module <
    people : PersonAPI.Short.t list ;
    groups : GroupAPI.Short.t list ;
    info   : ChatInfo.t ;
  >

  let path = "chat/{id}"

  let response req arg = 
    let! info = Chat.get (arg # id) in 
    match info with None -> return (not_found (arg # id)) | Some info -> 
      let! people = List.M.filter_map Person.get (info # people) in 
      let! groups = Group.get_many (req # as_) (info # groups) in 
      return (`OK (Out.make ~people ~groups:(groups :> Group.short list) ~info))

end)

module GetAllAs = Endpoint.Get(struct

  module Arg = type module unit
  module Out = type module <
    people : PersonAPI.Short.t list ;
    groups : GroupAPI.Short.t list ;
    list   : ChatInfo.t list ;
  >

  let path = "chat"

  let response req _ = 
    let  limit  = Option.default 100 (req # limit) in
    let  offset = Option.default 0 (req # offset) in
    let! list = Chat.all_as ~limit ~offset (req # as_) in
    let! groups = Group.get_many (req # as_) List.(unique (flatten (map (#groups) list))) in
    let! people = List.(M.filter_map Person.get
			    (unique (flatten (map (#people) list)))) in
    return (`OK (Out.make ~people ~groups:(groups :> Group.short list) ~list))

end)

(* Obtaining chat contents 
   ======================= *)

module Item = type module <
  id     : Chat.MI.t ;
  author : PId.t ;
  time   : Time.t ; 
  body   : String.Rich.t ;
>

module Items = Endpoint.Get(struct

  module Arg = type module < id : Chat.I.t >
  module Out = type module <
    items  : Item.t list ;
    people : PersonAPI.Short.t list ;
    count  : int 
  >

  let path = "chat/{id}/items"

  let response req arg = 
    let! info = Chat.get (arg # id) in
    match info with None -> return (not_found (arg # id)) | Some info -> 
      let  count = info # count in 
      let! items = Chat.list ?limit:(req # limit) ?offset:(req # offset) (arg # id) in
      let  cids  = List.unique (List.map (#author) items) in
      let! people = List.M.filter_map Person.get cids in
      return (`OK (Out.make ~items ~people ~count))

end)
