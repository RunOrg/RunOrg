(* © 2014 RunOrg *)

open Std

module Create = Endpoint.Post(struct

  module Arg = type module unit
  module Post = type module <
    from : CId.t ;
    subject : Unturing.t ;
   ?text : Unturing.t option ;
   ?html : Unturing.t option ;
    audience : Mail.Access.Audience.t ;
   ?urls : String.Url.t list = [] ;
   ?custom : Json.t = Json.Null ;
  >

  module Out = type module <
    id : Mail.I.t ;
    at : Cqrs.Clock.t ;
  >

  let path = "mail/create"

  let needAccess id = 
    `Forbidden (!! "Not allowed to create mail in database %S." (Id.to_string id))

  let response req () post = 
    
    let! result = Mail.create (req # as_) 
      ~from:(post # from) ~subject:(post # subject) 
      ?text:(post # text) ?html:(post # html) 
      ~urls:(post # urls) ~custom:(post # custom) (post # audience) in
    
    match result with 
    | `NeedAccess id -> return (needAccess id)
    | `OK   (id, at) -> return (`OK (Out.make ~id ~at))

end)
