(* © 2014 RunOrg *)

open Std

(* Group information 
   ================= *)

type short = <
  id     : GId.t ;
  label  : String.Label.t option ; 
  access : GroupAccess.Set.t ;
  count  : int option ;
>

type info = <
  id       : GId.t ; 
  label    : String.Label.t option ;
  access   : GroupAccess.Set.t ;
  count    : int option ;
  audience : GroupAccess.Audience.t option ; 
>

let format_info gid access info = object
  method id       = gid
  method access   = access
  method label    = info # label
  method count    = if Set.mem `List access then Some (info # count) else None
  method audience = if Set.mem `Admin access then Some (info # audience) else None
end 

let get pid gid = 
  let! info = Cqrs.MapView.get View.info gid in
  match info with None -> return None | Some info ->
    let! access = GroupAccess.compute pid (info # audience) in
    if not (Set.mem `View access) then return None else 
      return (Some (format_info gid access info))

let get_many pid gids = 
  let compute = GroupAccess.compute pid in 
  List.M.filter_map begin fun gid ->     
    let! info = Cqrs.MapView.get View.info gid in
    match info with None -> return None | Some info ->     
      let! access = compute (info # audience) in      
      if not (Set.mem `View access) then return None else
	return (Some (format_info gid access info))
  end gids

let all pid ~limit ~offset = 
  let! list = GroupAccess.Map.list ~limit ~offset View.byAccess pid `View in 
  let! list = get_many pid list in
  return (list :> short list) 

(* Members in the group 
   ==================== *)

let list pid ?limit ?offset gid = 

  let! info = Cqrs.MapView.get View.info gid in
  match info with None -> return (`NotFound gid) | Some info ->

    let! access = GroupAccess.compute pid (info # audience) in
    if not (Set.mem `View access) then return (`NotFound gid) else       
      if not (Set.mem `List access) then return (`NeedList gid) else

	  let! list  = Cqrs.ManyToManyView.list ?limit ?offset View.people gid in
	  return (`OK (list, info # count))

let list_force ?limit ?offset gid = 
  Cqrs.ManyToManyView.list ?limit ?offset View.people gid

(* Groups of a member
   ================== *)

let of_person cid = 
  let  groups = Cqrs.ManyToManyView.flip View.people in 
  let! list = Cqrs.ManyToManyView.list groups cid in
  return (Set.of_list list) 

let () = 
  Audience.register_groups_of_person of_person
