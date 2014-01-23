(* © 2014 RunOrg *)

open Std

module Create = Endpoint.Post(struct
    
  module Arg = type module unit
  module Post = type module unit

  module Out = type module <
    id : Chat.I.t ;
    at : Cqrs.Clock.t ;
  >

  let path = "chat/create"

  let response req () () = 
    let! id, at = Chat.create () in
    return (`Accepted (Out.make ~id ~at))

end)
