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

  let needViewProfile pid = 
    `Forbidden (!! "Not allowed to view profile of sender %S." (PId.to_string pid)) 

  let response req () post = 
    
    let self = match post # self with None -> None | Some self ->      
      match String.Url.of_string_template "id" self with None -> None | Some url -> 
	Some (fun id -> url (Mail.I.to_string id)) in
	
    let! result = Mail.create (req # as_) 
      ~from:(post # from) ~subject:(post # subject) 
      ?text:(post # text) ?html:(post # html) 
      ~urls:(post # urls) ~custom:(post # custom) ?self (post # audience) in
    
    match result with 
    | `NeedAccess       id -> return (needAccess id)
    | `NeedViewProfile pid -> return (needViewProfile pid) 
    | `OK         (id, at) -> return (`Accepted (Out.make ~id ~at))

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
  module Post = type module < 
    ?group : GId.t option ;
    ?people : PId.t list = [] ;
  >

  module Out  = type module < 
    count : int ;
    at    : Cqrs.Clock.t ;
  >

  let needAccess id = 
    `Forbidden (!! "Not allowed to send mail in database %S." (Id.to_string id))

  let needList id =
    `NotFound (!! "Not allowed to list members of group %S." (GId.to_string id)) 

  let groupNotFound id =
    `NotFound (!! "Group %S does not exist." (GId.to_string id)) 
      
  let needRecipient = 
    `BadRequest "Need either non-null 'group:' or a non-empty 'people:' list."

  let path = "mail/{id}/send"

  let response req arg post = 
    match post # group, post # people with 
    | Some group, [] -> begin

      let! result = SentMail.send (req # as_) (arg # id) group in
      match result with 
      | `NeedAccess       id -> return (needAccess id)
      | `NeedList        gid -> return (needList gid)
      | `NoSuchMail      mid -> return (notFound mid) 
      | `NoSuchGroup     gid -> return (groupNotFound gid) 
      | `GroupEmpty        _ -> return (`Accepted (Out.make ~count:0 ~at:Cqrs.Clock.empty))
      | `OK (wid, count, at) -> return (`Accepted (Out.make ~count ~at))

    end 
    | None, [] -> return needRecipient    
    | None, people -> begin

      let! result = SentMail.sendToPeople (req # as_) (arg # id) people in
      match result with 
      | `NeedAccess       id -> return (needAccess id)
      | `NoSuchMail      mid -> return (notFound mid) 
      | `OK (wid, count, at) -> return (`Accepted (Out.make ~count ~at))

    end
    | _ -> return needRecipient

end)

(* Sending statistics 
   ================== *)

module Stats = Endpoint.Get(struct

  module Arg = type module < id : Mail.I.t >
  module Out = type module <
    scheduled : int ;
    sent : int ;
    failed : int ;
    opened : int ;
    clicked : int ;
  >

  let needAdmin mid = 
    `Forbidden (!! "You need admin access to view statistics for e-mail %S." (Mail.I.to_string mid))

  let path = "mail/{id}/stats"

  let response req arg = 
    let! stats = SentMail.stats (req # as_) (arg # id) in
    match stats with 
    | `NoSuchMail mid -> return (notFound mid) 
    | `NeedAdmin  mid -> return (needAdmin mid) 
    | `OK stats -> return (`OK (stats :> Out.t))

end)

(* Sent e-mail information and preview. 
   ==================================== *)

module GetSent = Endpoint.Get(struct

  module Arg = type module <
    id       : Mail.I.t ;
    pid "to" : PId.t ;
  >

  module Out = type module <
    status : SentMail.Status.t ;
    sent   : Time.t option ;
    view   : <
      from     : < name : string option ; email : string > ;
      to_ "to" : < name : string option ; email : string > ;
      subject  : string ;
      html     : string option ;
      text     : string option ; 
    >
  >

  let path = "mail/{id}/to/{to}"

  let forbidden id = 
    `Forbidden (!! "Not allowed to view mail for recipient %S." (PId.to_string id))

  let senderNotFound id =
    `NotFound (!! "Sender %S does not exist." (PId.to_string id)) 

  let templateError s (t,l,c) = 
    `InternalError (!! "Template error in '%s' at line %d, char %d: %s" s (l + 1) (c + 1) t) 

  let response req arg = 

    let! mail = Mail.get (arg # id) in
    match mail with None -> return (notFound (arg # id)) | Some mail ->

      let! access = Mail.Access.compute (req # as_) (mail # audience) in
      let  canPreview = Set.mem `View access in
      let  canView = req # as_ = Some (arg # pid) || Set.mem `Admin access in 
      
      if not canView && canPreview then return (forbidden (arg # pid)) else
	if not canView && not canPreview then return (notFound (arg # id)) else
	  	  
	  let! info = SentMail.get mail (arg # pid) in
	  match info with 
	  | Bad  `NoInfoAvailable
	  | Bad  `NoSuchRecipient   -> return (notFound (arg # id))
	  | Bad (`NoSuchSender pid) -> return (senderNotFound pid)
	  | Bad (`SubjectError e)   -> return (templateError "subject" e)
	  | Bad (`TextError    e)   -> return (templateError "text" e)
	  | Bad (`HtmlError    e)   -> return (templateError "html" e)
	  | Bad (`Exception    e)   -> return (`InternalError e)
	  | Ok info -> 

	    if info # status <> `Sent && not canPreview then return (notFound (arg # id)) else 
	     
	      return (`OK (info :> Out.t))

end)

(* Following links
   =============== *)

module Follow = Endpoint.RawGet(struct
    
  module Arg = type module < link : SentMail.Link.t >

  let path = "link/{link}"

  let notFound = 
    Httpd.raw 
      ~headers:[ "Content-Type", "text/html" ]
      ~status:`NotFound
      "<!DOCTYPE html><html><head><title>404 Not Found</title></head><body><h1>404 Not Found</h1></body>"

  let redirect url = 
    let url = String.Url.to_string url in 
    Httpd.raw
      ~headers:[ "Location", url ]
      ~status:`Found
      url

  let track = 
    Httpd.raw 
      ~headers:[ "Content-Type", "image/gif" ]
      ~status:`OK 
      ("\x47\x49\x46\x38\x39\x61\x01\x00\x01\x00\x80\x00\x00\xff\xff\xff"
       ^ "\x00\x00\x00\x2c\x00\x00\x00\x00\x01\x00\x01\x00\x00\x02\x02\x44\x01\x00\x3b")

  let response req arg = 
    let! follow = SentMail.follow (arg # link) (req # client_ip) in
    match follow with 
    | `NotFound (_,_) -> return notFound
    | `Track          -> return track  
    | `Link url       -> return (redirect url)
    | `Auth (tok,url) -> let tok = Token.I.to_string tok in
			 let url = String.Url.add_query_string_parameter "runorg" tok url in
			 return (redirect url) 

end)
