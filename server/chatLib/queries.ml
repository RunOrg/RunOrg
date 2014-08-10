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

let format_info id access info = object
  method id       = id 
  method count    = if Set.mem `Read access then Some (info # count) else None
  method root     = if Set.mem `Read access then Some (info # root) else None
  method last     = if Set.mem `Read access then Some (info # last) else None
  method subject  = info # subject
  method audience = if Set.mem `Admin access then Some (info # audience) else None   
  method access   = access
  method custom   = info # custom
  method track    = false
end


let get pid cid = 
  let! info = Cqrs.MapView.get View.info cid in 
  match info with None -> return None | Some info -> 

    let! access = ChatAccess.compute pid (info # audience) in 
    if not (Set.mem `View access) then return None else

      return (Some (format_info cid access info))

let get_many pid cids = 
  let compute = ChatAccess.compute pid in 
  List.M.filter_map begin fun cid -> 
    let! info = Cqrs.MapView.get View.info cid in 
    match info with None -> return None | Some info ->
      let! access = compute (info # audience) in
      if not (Set.mem `View access) then return None else
	return (Some (format_info cid access info))
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

let rec transform node = (object

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

  val sub = List.map transform (node # subtree)
  method sub = sub

  method track = false

end : post)

let list pid ?(depth=1) ?(limit=1000) ?(offset=0) ?parent cid = 
  let! info = get pid cid in
  match info with None -> return (`NotFound cid) | Some info ->
    
    if not (Set.mem `Read (info # access)) then return (`NeedRead info) else

      let! list = Cqrs.TreeMapView.list View.posts ~depth ~limit ~offset ?parent cid in 
      let  list = List.map transform list in 

      let! count = match parent with 
	| None -> return (Option.default 0 (info # root))
	| Some id -> 

	  let! node = Cqrs.TreeMapView.get View.posts cid id in
	  return (match node with None -> 0 | Some node -> node # count) 

      in

      return (`OK (count, list))

let unread pid ?limit ?offset who = 
  assert false
