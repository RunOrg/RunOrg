(* © 2014 RunOrg *)

open Std

module Create = Endpoint.Post(struct

  module Arg = type module unit
  module Post = type module <
    from : CId.t ;
    subject : String.Label.t ;
   ?text : string option ;
   ?html : String.Rich.t option ;
    audience : Mail.Access.Audience.t ;
  >

  module Out = type module <
    id : Mail.I.t ;
    at : Cqrs.Clock.t ;
  >

  let path = "mail/create"

  let response req () post = 
    let! id, at = 
      Mail.create (req # as_) ~from:(post # from) ~subject:(post # subject) 
	?text:(post # text) ?html:(post # html) (post # audience) in
    return (`OK (Out.make ~id ~at))

end)
