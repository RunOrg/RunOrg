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
   ?self : string option = None ; 
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
    
    let self = match post # self with None -> None | Some self ->      
      match String.Url.of_string_template "id" self with None -> None | Some url -> 
	Some (fun id -> url (Mail.I.to_string id)) in
	
    let! result = Mail.create (req # as_) 
      ~from:(post # from) ~subject:(post # subject) 
      ?text:(post # text) ?html:(post # html) 
      ~urls:(post # urls) ~custom:(post # custom) ?self (post # audience) in
    
    match result with 
    | `NeedAccess id -> return (needAccess id)
    | `OK   (id, at) -> return (`OK (Out.make ~id ~at))

end)
