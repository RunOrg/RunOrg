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
	       return (`OK (Out.make ~id ~at))

end)
