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

(* Updating a chatroom 
   =================== *)

let update pid ~subject ~custom ~audience id = 
  
  let! info = Cqrs.MapView.get View.info id in
  match info with None -> return (`NotFound id) | Some info -> 

    let! access = ChatAccess.compute pid (info # audience) in
    if not (Set.mem `View access) then return (`NotFound id) else
      if not (Set.mem `Admin access) then return (`NeedAdmin id) else

	if subject = `Keep && custom = `Keep && audience = `Keep then
	  return (`OK Cqrs.Clock.empty)
	else

	  let! clock = Store.append [ Events.chatUpdated ~id ~pid ~subject ~custom ~audience ] in
	  return (`OK clock) 

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

let createPost id author body custom parent = 

  let! info = Cqrs.MapView.get View.info id in 
  match info with None -> return (`NotFound id) | Some info -> 

    let! access = ChatAccess.compute (Some author) (info # audience) in
    if not (Set.mem `View access) then return (`NotFound id) else
      if not (Set.mem `Write access) then return (`NeedPost id) else

      let  post = PostI.gen () in 
      let! clock = Store.append [ Events.postCreated ~id ~post ~author ~parent ~custom ~body ] in
      return (`OK (post, clock))

(* Deleting an item from a chatroom
   ================================ *)

let deletePost pid id post = 

  let! info = Cqrs.MapView.get View.info id in 
  match info with None -> return (`NotFound id) | Some info -> 

    let! access = ChatAccess.compute pid (info # audience) in
    if not (Set.mem `View access) then return (`NotFound id) else

      let! node = Cqrs.TreeMapView.get View.posts id post in
      match node with None -> return (`PostNotFound (id, post)) | Some node ->
	
	let item = node # value in 
	let required = if Some (item # author) = pid then `View else `Moderate in
	if not (Set.mem required access) then return (`NeedModerate id) else
	  
	  let! clock = Store.append [ Events.postDeleted ~id ~pid ~post ] in
	  return (`OK clock) 
	  
(* Tracking posts 
   ============== *)

let track pid ?(unsubscribe=false) ?under id = 

  let! info = Cqrs.MapView.get View.info id in 
  match info with None -> return (`NotFound id) | Some info -> 

    let! access = ChatAccess.compute (Some pid) (info # audience) in
    if not (Set.mem `View access) then return (`NotFound id) else
      if not (Set.mem `Read access) then return (`NeedRead id) else

	let! postNotFound = match under with None -> return None | Some post ->
	  let! node = Cqrs.TreeMapView.get View.posts id post in
	  match node with None -> return (Some (`PostNotFound (id, post))) | Some _ -> return None in
	match postNotFound with Some err -> return err | None -> 

	  (* The post and chat exist and are available *)

	  let! tracked = Cqrs.TripleSetView.intersect View.trackers id under [pid] in
	  if (tracked = []) = unsubscribe then return (`OK Cqrs.Clock.empty) else 	    
	    let! clock = Store.append [
	      if unsubscribe then Events.trackDisabled ~id ~pid ~post:under
	      else Events.trackEnabled ~id ~pid ~post:under
	    ] in 
	    return (`OK clock) 

let markAsRead pid id posts = 

  let! info = Cqrs.MapView.get View.info id in 
  match info with None -> return (`NotFound id) | Some info -> 

    let! access = ChatAccess.compute (Some pid) (info # audience) in
    if not (Set.mem `View access) then return (`NotFound id) else
      if not (Set.mem `Read access) then return (`NeedRead id) else
	
	(* The chat exists and is available *)

	let! posts = Cqrs.TripleSetView.(intersect (flipBC View.unread) id pid posts) in 

	if posts = [] then return (`OK Cqrs.Clock.empty) else
	  let! clock = Store.append [ Events.markedAsRead ~id ~pid ~posts ] in
	  return (`OK clock) 

