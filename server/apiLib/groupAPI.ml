(* © 2014 RunOrg *)

open Std

let notFound gid = 
  `NotFound (!! "Group '%s' does not exist." (GId.to_string gid))

module Create = Endpoint.Post(struct

  module Arg = type module unit
  module Post = type module <
    ?id       : string option ; 
    ?label    : String.Label.t option ;
    ?audience : Group.Access.Audience.t = Map.empty ;
  >

  module Out = type module <
    id : GId.t ;
    at : Cqrs.Clock.t ;
  >

  let path = "groups"

  let alreadyExists id = 
    `Conflict (!! "Identifier %S is already taken." (CustomId.to_string id))

  let needAccess id = 
    `Forbidden (!! "Not allowed to create groups in database %S." (Id.to_string id))

  let response req () post = 
    match Option.bind (post # id) CustomId.validate, post # id with 
    | None, Some id -> return (`BadRequest (!! "%S is not a valid identifier" id))
    | _, Some "admin" -> return (`Conflict "Group 'admin' is a reserved identifier")
    | id, _ -> let! result = Group.create (req # as_) ?id ?label:(post # label) (post # audience) in
	       match result with 
	       | `OK       (id,at) -> return (`Accepted (Out.make ~id ~at))
	       | `NeedAccess    id -> return (needAccess id)
	       | `AlreadyExists id -> return (alreadyExists id)

end)

module Add = Endpoint.Post(struct

  module Arg = type module < id : GId.t >
  module Post = type module (PId.t list)
  module Out = type module < at : Cqrs.Clock.t >

  let path = "groups/{id}/add"

  let needModerator gid = 
    `Forbidden (!! "You need 'moderate' access to add people to group %S." (GId.to_string gid))

  let response req args post = 
    let! result = Group.add (req # as_) post [ args # id ] in
    match result with 
    | `OK            at -> return (`Accepted (Out.make ~at))
    | `NeedModerator id -> return (needModerator id)
    | `NotFound      id -> return (notFound id)

end)

module Remove = Endpoint.Post(struct

  module Arg = type module < id : GId.t >
  module Post = type module (PId.t list) 
  module Out = type module < at : Cqrs.Clock.t >

  let path = "groups/{id}/remove"

  let needModerator gid = 
    `Forbidden (!! "You need 'moderate' access to remove people from group %S." (GId.to_string gid))

  let response req args post = 
    let! result = Group.remove (req # as_) post [ args # id ] in
    match result with 
    | `OK            at -> return (`Accepted (Out.make ~at))
    | `NeedModerator id -> return (needModerator id)
    | `NotFound      id -> return (notFound id)

end)

module Get = Endpoint.Get(struct

  module Arg = type module < id : GId.t >
  module Out = type module <
    list  : PersonAPI.Short.t list ; 
    count : int ;
  >

  let path = "groups/{id}"

  let response req args = 
    let limit = Option.default 1000 (req # limit) in
    let offset = Option.default 0 (req # offset) in
    let! cids, count = Group.list ~limit ~offset (args # id) in
    let! list = List.M.filter_map Person.get cids in 
    return (`OK (Out.make ~list ~count))

end)

module Info = type module <
  id    : GId.t ;
  label : String.Label.t option ; 
  count : int ;
>

module GetInfo = Endpoint.Get(struct

  module Arg = type module < gid : GId.t >
  module Out = Info

  let path = "groups/{gid}/info"

  let response req args = 
    let! group_opt = Group.get (args # gid) in
    match group_opt with Some group -> return (`OK group) | None ->
      return (notFound (args # gid))

end)

module Delete = Endpoint.Delete(struct

  module Arg = type module < id : GId.t >
  module Out = type module < at : Cqrs.Clock.t >

  let path = "groups/{id}"

  let needAdmin gid = 
    `Forbidden (!! "You need 'admin' access to delete group %S." (GId.to_string gid))

  let response req args = 
    if GId.is_admin (args # id) then 
      return (`Forbidden "Group 'admin' cannot be deleted.")
    else 
      let! result = Group.delete (req # as_) (args # id) in
      match result with 
      | `OK         at -> return (`Accepted (Out.make ~at))
      | `NotFound  gid -> return (notFound gid)
      | `NeedAdmin gid -> return (needAdmin gid)

end)

module AllPublic = Endpoint.Get(struct

  module Arg = type module unit
  module Out = type module < list : Info.t list ; count : int >
  
  let path = "groups/public"

  let response req () = 
    let limit = Option.default 1000 (req # limit) in
    let offset = Option.default 0 (req # offset) in    
    let! list, count = Group.all ~limit ~offset in
    return (`OK (Out.make ~list ~count))

end)
