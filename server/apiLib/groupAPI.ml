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

module Update = Endpoint.Put(struct

  module Arg = type module < id : GId.t >
  module Put = type module <
    ?label    : String.Label.t option ;
    ?audience : Group.Access.Audience.t option ;
  >

  module Out = type module < at : Cqrs.Clock.t >

  let needAdmin gid = 
    `Forbidden (!! "You need 'admin' access to update group %S." (GId.to_string gid))

  let path = "groups/{id}/info"

  let response req arg put =
    let label = Change.of_field "label" (req # body) (put # label) in
    let audience = Change.of_option (put # audience) in
    let! result = Group.update (req # as_) ~label ~audience (arg # id) in
    match result with 
    | `OK        at -> return (`Accepted (Out.make ~at))
    | `NeedAdmin id -> return (needAdmin id)
    | `NotFound  id -> return (notFound id)

end)

module Add = Endpoint.Post(struct

  module Arg = type module < id : GId.t >
  module Post = type module (PId.t list)
  module Out = type module < at : Cqrs.Clock.t >

  let path = "groups/{id}/add"

  let needModerator gid = 
    `Forbidden (!! "You need 'moderate' access to add people to group %S." (GId.to_string gid))

  let missingPerson pid = 
    `NotFound (!! "Person %S does not exist." (PId.to_string pid))

  let response req args post = 
    let! result = Group.add (req # as_) post [ args # id ] in
    match result with 
    | `OK            at -> return (`Accepted (Out.make ~at))
    | `NeedModerator id -> return (needModerator id)
    | `NotFound      id -> return (notFound id)
    | `MissingPerson id -> return (missingPerson id) 

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

  let needList gid = 
    `Forbidden (!! "You need 'list' access to group %S." (GId.to_string gid))

  let response req args = 
    let limit = Option.default 1000 (req # limit) in
    let offset = Option.default 0 (req # offset) in
    let! listing = Group.list (req # as_) ~limit ~offset (args # id) in
    match listing with 
    | `NotFound gid -> return (notFound gid)
    | `NeedList gid -> return (needList gid) 
    | `OK (list, count) -> 

      let! list = List.M.filter_map Person.get list in 
      return (`OK (Out.make ~list ~count))

end)

module Info = type module <
  id       : GId.t ;
  label    : String.Label.t option ; 
  access   : Group.Access.Set.t ;
  count    : int option ;
  audience : Group.Access.Audience.t option ;
>

module Short = type module <
  id     : GId.t ;
  label  : String.Label.t option ; 
  access : Group.Access.Set.t ;
  count  : int option ;
>

module GetInfo = Endpoint.Get(struct

  module Arg = type module < gid : GId.t >
  module Out = Info

  let path = "groups/{gid}/info"

  let response req args = 
    let! group_opt = Group.get (req # as_) (args # gid) in
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

module All = Endpoint.Get(struct

  module Arg = type module unit
  module Out = type module < list : Short.t list >
  
  let path = "groups"

  let response req () = 
    let limit = Option.default 1000 (req # limit) in
    let offset = Option.default 0 (req # offset) in    
    let! list = Group.all (req # as_) ~limit ~offset in
    return (`OK (Out.make ~list))

end)
