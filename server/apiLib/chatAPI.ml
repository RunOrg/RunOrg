(* © 2014 RunOrg *)

open Std

module Create = Endpoint.Post(struct
    
  module Arg = type module unit
  module Post = type module <
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
      match post # contacts with 
      | [ a ; b ] when a <> b -> 
	let! id, at = Chat.createPM a b in
	return (`Accepted (Out.make ~id ~at))
      | _ -> return (`BadRequest "Invalid parameters for private message thread")
    else
      if post # contacts = [] && post # groups = [] then
	return (`BadRequest "Please provide at least one contact or group")
      else
	let! id, at = Chat.create (post # contacts) (post # groups) in 
	return (`Accepted (Out.make ~id ~at))
	
end)
