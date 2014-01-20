(* © 2014 RunOrg *)

open Std

module Create = Endpoint.Post(struct

  module Arg = type module unit
  module Post = type module <
    ?id    : string option ; 
    ?label : string option ;
  >

  module Out = type module <
    id : Group.I.t ;
    at : Cqrs.Clock.t ;
  >

  let path = "groups/create"

  let response req () post = 
    match Option.bind (post # id) CustomId.validate, post # id with 
    | None, Some id -> return (`BadRequest (!! "%S is not a valid identifier" id))
    | id, _ -> let! id, at = Group.create ?id ?label:(post # label) () in
	       return (`Accepted (Out.make ~id ~at))

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

module Delete = Endpoint.Delete(struct

  module Arg = type module < id : Group.I.t >
  module Out = type module < at : Cqrs.Clock.t >

  let path = "groups/{id}"

  let response req args = 
    (* TODO: check for existence *)
    let! at = Group.delete (args # id) in
    return (`Accepted (Out.make ~at))

end)
