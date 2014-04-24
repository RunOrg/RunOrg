(* © 2014 RunOrg *)

open Std

(* Creating a group
   ================ *)

(* Who is allowed to create new groups ? *)
let create_audience = Audience.admin 

let create pid ?label ?id audience = 

  let! id = match id with 
    | None -> return (Ok (GId.gen ()))
    | Some id -> let gid = GId.of_id (CustomId.to_id id) in
		 let! exists = Cqrs.SetView.exists View.exists gid in 
		 return (if exists then Bad id else Ok gid)
  in

  match id with Bad id -> return (`AlreadyExists id) | Ok id -> 

    let! allowed = Audience.is_member pid create_audience in 

    if not allowed then 
      let! ctx = Run.context in 
      return (`NeedAccess (ctx # db))
    else

      let! clock = Store.append [ Events.created ~pid ~id ~label ~audience ] in
      return (`OK (id, clock))

(* Adding and removing from the group
   ================================== *)

let add_internal pid people groups = 
  if people = [] || groups = [] then return Cqrs.Clock.empty else
    Store.append [ Events.added ~pid ~people ~groups ] 

let add_forced people groups = 
  add_internal None people groups

let with_moderator_rights pid groups f = 

  let  compute = GroupAccess.compute pid in 

  let! accesses = List.M.map begin fun id -> 
    let! info = Cqrs.MapView.get View.info id in
    match info with None -> return (Bad id) | Some info -> 
      let! access = compute (info # audience) in 
      return (if Set.mem `View access then Ok (access,id) else Bad id)
  end groups in

  match List.find_bad accesses with Some id -> return (`NotFound id) | None ->
    
    let not_mod = List.map begin function
      | Ok (access,id) -> if Set.mem `Moderate access then Ok () else Bad id
      | Bad id -> assert false (* Caught above *)
    end accesses in

    match List.find_bad not_mod with Some id -> return (`NeedModerator id) | None -> 

      f ()

let add pid people groups = 
  with_moderator_rights pid groups (fun () ->     
    let! at = add_internal pid people groups in 
    return (`OK at)) 
    
let remove pid people groups = 
  with_moderator_rights pid groups (fun () -> 

      let! at = 
	if people = [] || groups = [] then return Cqrs.Clock.empty else
	  Store.append [ Events.removed ~pid ~people ~groups ] in

      return (`OK at))    

(* Deleting the group 
   ================== *)
  
let delete pid id = 
  let! info = Cqrs.MapView.get View.info id in 
  match info with None -> return (`NotFound id) | Some info -> 

    let! access = GroupAccess.compute pid (info # audience) in
    
    if Set.mem `Admin access then 
      let! clock = Store.append [ Events.deleted ~pid ~id ] in
      return (`OK clock) 
    else if Set.mem `View access then
      return (`NeedAdmin id) 
    else
      return (`NotFound id) 
