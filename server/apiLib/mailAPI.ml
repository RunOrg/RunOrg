(* © 2014 RunOrg *)

open Std

(* Creating new drafts
   =================== *)

module Create = Endpoint.Post(struct

  module Arg = type module unit
  module Post = type module <
    from : PId.t ;
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

  let path = "mail"

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
    | `OK   (id, at) -> return (`Accepted (Out.make ~id ~at))

end)

(* Querying draft data 
   =================== *)

let notFound id = `NotFound (!! "Mail draft %S does not exist." (Mail.I.to_string id)) 

module Get = Endpoint.Get(struct

  module Arg = type module < id : Mail.I.t >
  module Out = type module <
    id : Mail.I.t ;
    from : PersonAPI.Short.t option ;
    subject : Unturing.t ;
    text : Unturing.t option ;
    html : Unturing.t option ;
    audience : Mail.Access.Audience.t option ;
    access : Mail.Access.Set.t ;
    urls : String.Url.t list ;
    self : String.Url.t option ;
    custom : Json.t ;
  > 

  let path = "mail/{id}"

  let response req arg = 
    
    let! mail = Mail.get (arg # id) in
    match mail with None -> return (notFound (arg # id)) | Some mail ->

      let! access = Mail.Access.compute (req # as_) (mail # audience) in
      if not (Set.mem `View access) then return (notFound (arg # id)) else
      
	let audience = if Set.mem `Admin access then Some (mail # audience) else None in 

	let! from = Person.get (mail # from) in
	return (`OK (Out.make ~id:(arg # id) ~from ~subject:(mail # subject)
		       ~text:(mail # text) ~html:(mail # html) ~audience
		       ~access ~urls:(mail # urls) ~self:(mail # self)
		       ~custom:(mail # custom)))

end)

(* Sending e-mail. 
   =============== *)

module Send = Endpoint.Post(struct

  module Arg  = type module < id : Mail.I.t >
  module Post = type module < group : GId.t >

  module Out  = type module < 
    count : int ;
    at    : Cqrs.Clock.t ;
  >

  let needAccess id = 
    `Forbidden (!! "Not allowed to send mail in database %S." (Id.to_string id))

  let groupNotFound id =
    `NotFound (!! "Group %S does not exist." (GId.to_string id)) 

  let path = "mail/{id}/send"

  let response req arg post = 
    let! result = SentMail.send (req # as_) (arg # id) (post # group) in
    match result with 
    | `NeedAccess       id -> return (needAccess id)
    | `NoSuchMail      mid -> return (notFound mid) 
    | `NoSuchGroup     gid -> return (groupNotFound gid) 
    | `GroupEmpty        _ -> return (`Accepted (Out.make ~count:0 ~at:Cqrs.Clock.empty))
    | `OK (wid, count, at) -> return (`Accepted (Out.make ~count ~at))

end)
