(* © 2014 RunOrg *)

open Std

(* Creating a chatroom
   =================== *)

(* Who is allowed to create new chatrooms ? *)
let create_audience = Audience.admin 

let create pid ?subject ?(custom=Json.Null) audience = 

  let! allowed = Audience.is_member pid create_audience in
  
  if not allowed then 
    let! ctx = Run.context in 
    return (`NeedAccess (ctx # db))
  else

    let  id = I.gen () in 
    let! clock = Store.append [ Events.chatCreated ~id ~pid ~subject ~audience ~custom ] in
    return (`OK (id, clock)) 

(* Deleting a chatroom 
   =================== *)

let delete pid id = 

  let! info = Cqrs.MapView.get View.info id in 
  match info with None -> return (`NotFound id) | Some info -> 

    let! access = ChatAccess.compute pid (info # audience) in
    if not (Set.mem `View access) then return (`NotFound id) else
      if not (Set.mem `Admin access) then return (`NeedAdmin id) else
	
	let! clock = Store.append [ Events.chatDeleted ~id ~pid ] in
	return (`OK clock) 

(* Posting to a chatroom 
   ===================== *)

let createPost id author body = 

  let! info = Cqrs.MapView.get View.info id in 
  match info with None -> return (`NotFound id) | Some info -> 

    let! access = ChatAccess.compute (Some author) (info # audience) in
    if not (Set.mem `View access) then return (`NotFound id) else
      if not (Set.mem `Write access) then return (`NeedPost id) else

      let  post = PostI.gen () in 
      let! clock = Store.append [ Events.postCreated ~id ~post ~author ~body ] in
      return (`OK (post, clock))

(* Deleting an item from a chatroom
   ================================ *)

let deletePost pid id post = 

  let! info = Cqrs.MapView.get View.info id in 
  match info with None -> return (`NotFound id) | Some info -> 

    let! item = Cqrs.FeedMapView.get View.posts id post in
    match item with None -> return (`PostNotFound (id, post)) | Some (_,item) ->

      let required = if Some (item # author) = pid then `View else `Moderate in
      let! access = ChatAccess.compute pid (info # audience) in
      if not (Set.mem `View access) then return (`NotFound id) else
	if not (Set.mem required access) then return (`NeedModerate id) else
	  
	  let! clock = Store.append [ Events.postDeleted ~id ~pid ~post ] in
	  return (`OK clock) 
	  
