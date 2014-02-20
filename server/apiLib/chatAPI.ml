(* © 2014 RunOrg *)

open Std

module Create = Endpoint.Post(struct
    
  module Arg = type module unit
  module Post = type module <
    ?subject  : String.Label.t option ; 
    ?contacts : CId.t list     = [] ;
    ?groups   : Group.I.t list = [] ;
    ?pm       : bool           = false ;
  >

  module Out = type module <
    id : Chat.I.t ;
    at : Cqrs.Clock.t ;
  >

  let path = "chat/create"

  let response req () post =
    if post # pm then 
      if post # subject = None then 
	match post # contacts with 
	| [ a ; b ] when a <> b -> 
	  let! id, at = Chat.createPM a b in
	  return (`Accepted (Out.make ~id ~at))
	| _ -> return (`BadRequest "Invalid parameters for private message thread")
      else
	return (`BadRequest "No subject allowed for private message thread")
    else
      if post # contacts = [] && post # groups = [] then
	return (`BadRequest "Please provide at least one contact or group")
      else
	let! id, at = Chat.create ?subject:(post # subject) (post # contacts) (post # groups) in 
	return (`Accepted (Out.make ~id ~at))
	
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
    author : CId.t ;
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
  id : Chat.I.t ;
  subject : String.Label.t option ;
  contacts : CId.t list ;
  groups : Group.I.t list ;
  count : int ;
>

module Get = Endpoint.Get(struct

  module Arg = type module < id : Chat.I.t >
  module Out = type module <
    contacts : ContactAPI.Short.t list ;
    groups   : GroupAPI.Info.t list ;
    info     : ChatInfo.t ;
  >

  let path = "chat/{id}"

  let response req arg = 
    let! info = Chat.get (arg # id) in 
    match info with None -> return (not_found (arg # id)) | Some info -> 
      let! contacts = List.M.filter_map Contact.get (info # contacts) in 
      let! groups   = List.M.filter_map Group.get (info # groups) in 
      return (`OK (Out.make ~contacts ~groups ~info))

end)

(* Obtaining chat contents 
   ======================= *)

module Item = type module <
  id     : Chat.MI.t ;
  author : CId.t ;
  time   : Time.t ; 
  body   : String.Rich.t ;
>

module Items = Endpoint.Get(struct

  module Arg = type module < id : Chat.I.t >
  module Out = type module <
    items    : Item.t list ;
    contacts : ContactAPI.Short.t list ;
    count    : int 
  >

  let path = "chat/{id}/items"

  let response req arg = 
    let! info = Chat.get (arg # id) in
    match info with None -> return (not_found (arg # id)) | Some info -> 
      let  count = info # count in 
      let! items = Chat.list ?limit:(req # limit) ?offset:(req # offset) (arg # id) in
      let  cids  = List.unique (List.map (#author) items) in
      let! contacts = List.M.filter_map Contact.get cids in
      return (`OK (Out.make ~items ~contacts ~count))

end)
