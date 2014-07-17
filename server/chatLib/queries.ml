(* © 2014 RunOrg *)

open Std

(* Reading generic information 
   =========================== *)

type info = <
   id       : I.t ; 
   count    : int option ;
   last     : Time.t option ;
   audience : ChatAccess.Audience.t option ;
   subject  : String.Label.t option ;
   access   : ChatAccess.Set.t ;
>

let format_info id access info = object
  method id       = id 
  method count    = if Set.mem `Read access then Some (info # count) else None
  method last     = if Set.mem `Read access then Some (info # last) else None
  method subject  = info # subject
  method audience = if Set.mem `Admin access then Some (info # audience) else None   
  method access   = access
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
>

let list pid ?(limit=1000) ?(offset=0) cid = 
  let! info = get pid cid in
  match info with None -> return (`NotFound cid) | Some info ->
    
    if not (Set.mem `Read (info # access)) then return (`NeedRead info) else

      let! list = Cqrs.FeedMapView.list View.posts ~limit ~offset cid in 
      let  list = List.map (fun (id,t,value) -> (object
	method id = id
	method time = t
	method author = value # author
	method body = value # body
      end)) list in

      return (`OK (info, list))
