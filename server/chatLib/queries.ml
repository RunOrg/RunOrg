(* © 2014 RunOrg *)

open Std

(* Reading generic information 
   =========================== *)

type info = <
   id       : I.t ; 
   count    : int option ;
   root     : int option ; 
   last     : Time.t option ;
   audience : ChatAccess.Audience.t option ;
   subject  : String.Label.t option ;
   access   : ChatAccess.Set.t ;
   custom   : Json.t ; 
   track    : bool ;
>

let format_info id access track info = object
  method id       = id 
  method count    = if Set.mem `Read access then Some (info # count) else None
  method root     = if Set.mem `Read access then Some (info # root) else None
  method last     = if Set.mem `Read access then Some (info # last) else None
  method subject  = info # subject
  method audience = if Set.mem `Admin access then Some (info # audience) else None   
  method access   = access
  method custom   = info # custom
  method track    = track
end

let tracked pid cid = 
  match pid with None -> return false | Some pid ->
    let! list = Cqrs.TripleSetView.intersect View.trackers cid None [pid] in
    return (list <> []) 

let get pid cid = 
  let! info = Cqrs.MapView.get View.info cid in 
  match info with None -> return None | Some info -> 

    let! access = ChatAccess.compute pid (info # audience) in 
    if not (Set.mem `View access) then return None else

      let! tracked = tracked pid cid in
      return (Some (format_info cid access tracked info))

let get_many pid cids = 
  let compute = ChatAccess.compute pid in 
  List.M.filter_map begin fun cid -> 
    let! info = Cqrs.MapView.get View.info cid in 
    match info with None -> return None | Some info ->
      let! access = compute (info # audience) in
      if not (Set.mem `View access) then return None else
	let! tracked = tracked pid cid in
	return (Some (format_info cid access tracked info))
  end cids

(* Reading multiple chatrooms 
   ========================== *)

let all_as ?(limit=100) ?(offset=0) pid = 
  let! list = ChatAccess.Map.list ~limit ~offset View.byAccess pid `View in 
  get_many pid list 

(* Reading items 
   ============= *)

type post = <
  id     : PostI.t ;
  author : PId.t ;
  time   : Time.t ;
  body   : String.Rich.t ;
  custom : Json.t ; 
  count  : int ; 
  sub    : post list ;
  track  : bool ; 
>

let rec transform set node = (object

  val id = node # id
  method id = id

  val time = node # time
  method time = time

  val data = node # value
  method author = data # author
  method body = data # body
  method custom = data # custom 

  val count = node # count
  method count = count 

  val sub = List.map (transform set) (node # subtree)
  method sub = sub

  val track = Set.mem (Some (node # id)) set
  method track = track

end : post)

let list pid ?(depth=1) ?(limit=1000) ?(offset=0) ?parent cid = 
  let! info = get pid cid in
  match info with None -> return (`NotFound cid) | Some info ->
    
    if not (Set.mem `Read (info # access)) then return (`NeedRead info) else

      let! list = Cqrs.TreeMapView.list View.posts ~depth ~limit ~offset ?parent cid in 

      let! track = match pid with None -> return Set.empty | Some pid -> 
	let  list = List.map (fun node -> Some (node # id)) list in 
	let! list = Cqrs.TripleSetView.(intersect (flipBC View.trackers) cid pid list) in
	return (Set.of_list list)
      in

      let  list = List.map (transform track) list in 

      let! count = match parent with 
	| None -> return (Option.default 0 (info # root))
	| Some id -> 

	  let! node = Cqrs.TreeMapView.get View.posts cid id in
	  return (match node with None -> 0 | Some node -> node # count) 

      in

      return (`OK (count, list))

(* List unread posts for user
   ========================== *)

type unread = <
  chat   : I.t ;
  id     : PostI.t ;
  author : PId.t ;
  time   : Time.t ;
  body   : String.Rich.t ;
  custom : Json.t ; 
  count  : int ; 
>

let to_unread chat node = (object

  val chat = chat
  method chat = chat

  val id = node # id
  method id = id

  val time = node # time
  method time = time

  val data = node # value
  method author = data # author
  method body = data # body
  method custom = data # custom 

  val count = node # count
  method count = count 

end : unread) 

let unread pid ?(limit=10) ?(offset=0) who = 

  let! allowed = match pid with 
    | None -> return false
    | Some id when id = who -> return true
    | Some _ -> Audience.is_member pid Audience.admin in

  if not allowed then 
    let! ctx = Run.context in
    return (`NeedAccess (ctx # db))
  else

    let unread : (PId.t, I.t, PostI.t) Cqrs.TripleSetView.t = 
      Cqrs.TripleSetView.(View.unread |> flipBC |> flipAB) in

    let rec read chatCache postCache count =
      
      let! list = Cqrs.TripleSetView.all unread ~limit:count ~offset who in
      
      let rec process chatCache postCache found = function 
	| [] -> return (chatCache,postCache,found) 
	| (id,post) :: tail -> 
	
	  if found >= limit then return (chatCache,postCache,found) else 

	    let! allowed, chatCache = 
	      try return (Map.find id chatCache, chatCache) with Not_found ->
		let! allowed = 
		  let! info = Cqrs.MapView.get View.info id in 
		  match info with None -> return false | Some info -> 
		    let! access = ChatAccess.compute pid (info # audience) in 
		    return (Set.mem `Read access) 
		in
		return (allowed, Map.add id allowed chatCache) 
	    in
	    
	    if not allowed then process chatCache postCache found tail else
	      
	      let! info, postCache = 
		try return (Map.find (id,post) postCache, postCache) with Not_found -> 
		  let! info = 
		    let! node = Cqrs.TreeMapView.get View.posts id post in
		    match node with None -> return None | Some node -> 
		      return (Some (to_unread id node))
		  in
		  return (info, Map.add (id,post) info postCache)
	      in

	      process chatCache postCache (if info = None then found else (found + 1)) tail 

      in

      let! chatCache, postCache, found = process chatCache postCache 0 list in 

      if found < limit && count < limit * 8 then 
	read chatCache postCache (count * 2) 
      else
	
	let badChat = Map.to_list chatCache |> List.filter (fun (_,allowed) -> not allowed) |> List.map fst in
	let badPost = Map.to_list postCache |> List.filter (fun (_,d) -> d = None) |> List.map fst in
	let list = List.filter_map (fun k -> try Map.find k postCache with Not_found -> None) list in
	
	return (list, badChat, badPost)
	
    in

    let! list, badChat, badPost = read Map.empty Map.empty limit in

    return (`OK (object
      method list  = list 
      method erase = 
	let events = 
	  List.map (fun id -> Events.trackerGarbageCollected ~id ~pid:who) badChat
	  @ List.map (fun (id,post) -> Events.markedAsRead ~id ~posts:[post] ~pid:who) badPost
	in
	if events = [] then return () else
	  let! _ = Store.append events in 
	  return () 
    end))

(* List people who have not read a post yet
   ======================================== *)

(* Who is allowed to query unreaders *)
let unreaders_audience = Audience.admin

let unreaders pid ?(limit=1000) id post = 
  
  let! allowed = Audience.is_member pid unreaders_audience in 
  if not allowed then
    let! ctx = Run.context in
    return (`NeedAccess (ctx # db))
  else

    let! chat = Cqrs.MapView.get View.info id in
    match chat with None -> return (`NotFound id) | Some chat -> 

      let! exists = Cqrs.TreeMapView.exists View.posts id post in
      if not exists then return (`PostNotFound (id,post)) else

	let rec read personCache count = 
	  
	  let! list = Cqrs.TripleSetView.all2 View.unread ~limit:count ~offset:0 id post in
	  
	  let rec process personCache found = function 
	    | [] -> return (personCache, found) 
	    | head :: tail -> 
	      
	      if found >= limit then return (personCache, found) else 
	      
		let! personCache, allowed = 
		  try return (personCache, Map.find head personCache) with Not_found -> 
		    let! access = ChatAccess.compute (Some head) (chat # audience) in 
		    let  allowed = Set.mem `Read access in
		    return (Map.add head allowed personCache, allowed) 
		in
		
		process personCache (if allowed then found + 1 else found) tail

	  in

	  let! personCache, found = process personCache 0 list in

	  if found < limit && List.length list = limit && count < limit * 8 then
	    read personCache (2 * count) 
	  else
	    return (Map.to_list personCache)

	in

	let! people = read Map.empty limit in
	      
	let keep = people |> List.filter snd |> List.map fst in
	let discard = people |> List.filter (fun (_,a) -> not a) |> List.map fst in

	return (`OK (object
	  method list = keep 
	  method erase = 
	    let  events = List.map (fun pid -> Events.trackerGarbageCollected ~id ~pid) discard in
	    let! _ = Store.append events in
	    return ()
	end))
