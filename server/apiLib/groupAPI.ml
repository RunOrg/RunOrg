(* © 2014 RunOrg *)

open Std

module Create = Endpoint.Post(struct

  module Arg = type module unit
  module Post = type module <
    ?id    : string option ; 
    ?label : String.Label.t option ;
  >

  module Out = type module <
    id : Group.I.t ;
    at : Cqrs.Clock.t ;
  >

  let path = "groups/create"

  let alreadyExists id = 
    `Conflict (!! "Identifier %S is already taken." (CustomId.to_string id))

  let response req () post = 
    match Option.bind (post # id) CustomId.validate, post # id with 
    | None, Some id -> return (`BadRequest (!! "%S is not a valid identifier" id))
    | _, Some "admin" -> return (`Conflict "Group 'admin' is a reserved identifier")
    | id, _ -> let! result = Group.create ?id ?label:(post # label) () in
	       match result with 
	       | `OK       (id,at) -> return (`Accepted (Out.make ~id ~at))
	       | `AlreadyExists id -> return (alreadyExists id)

end)

module Add = Endpoint.Post(struct

  module Arg = type module < id : Group.I.t >
  module Post = type module (CId.t list)
  module Out = type module < at : Cqrs.Clock.t >

  let path = "groups/{id}/add"

  let response req args post = 
    let! at = Group.add post [ args # id ] in
    return (`Accepted (Out.make ~at))

end)

module Remove = Endpoint.Post(struct

  module Arg = type module < id : Group.I.t >
  module Post = type module (CId.t list) 
  module Out = type module < at : Cqrs.Clock.t >

  let path = "groups/{id}/remove"

  let response req args post = 
    let! at = Group.remove post [ args # id ] in
    return (`Accepted (Out.make ~at))

end)

module Get = Endpoint.Get(struct

  module Arg = type module < id : Group.I.t >
  module Out = type module <
    list  : ContactAPI.Short.t list ; 
    count : int ;
  >

  let path = "groups/{id}"

  let response req args = 
    let limit = Option.default 1000 (req # limit) in
    let offset = Option.default 0 (req # offset) in
    let! cids, count = Group.list ~limit ~offset (args # id) in
    let! list = List.M.filter_map Contact.get cids in 
    return (`OK (Out.make ~list ~count))

end)

module Info = type module <
  id    : Group.I.t ;
  label : String.Label.t option ; 
  count : int ;
>

module GetInfo = Endpoint.Get(struct

  module Arg = type module < gid : Group.I.t >
  module Out = Info

  let path = "groups/{gid}/info"

  let response req args = 
    let! group_opt = Group.get (args # gid) in
    match group_opt with Some group -> return (`OK group) | None ->
      return (`NotFound (!! "Group '%s' does not exist" (Group.I.to_string (args # gid))))

end)

module Delete = Endpoint.Delete(struct

  module Arg = type module < id : Group.I.t >
  module Out = type module < at : Cqrs.Clock.t >

  let path = "groups/{id}"

  let response req args = 
    (* TODO: check for existence *)
    if Group.I.is_admin (args # id) then 
      return (`Forbidden "Admin group cannot be deleted")
    else 
      let! at = Group.delete (args # id) in
      return (`Accepted (Out.make ~at))

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
