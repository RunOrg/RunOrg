(* © 2014 RunOrg *)

open Std

(* Creating a group
   ================ *)

(* Who is allowed to create new groups ? *)
let create_audience = Audience.admin 

let create cid ?label ?id audience = 

  let! id = match id with 
    | None -> return (Ok (GId.gen ()))
    | Some id -> let gid = GId.of_id (CustomId.to_id id) in
		 let! exists = Cqrs.SetView.exists View.exists gid in 
		 return (if exists then Bad id else Ok gid)
  in

  match id with Bad id -> return (`AlreadyExists id) | Ok id -> 

    let! allowed = Audience.is_member cid create_audience in 

    if not allowed then 
      let! ctx = Run.context in 
      return (`NeedAccess (ctx # db))
    else

      let! clock = Store.append [ Events.created ~cid ~id ~label ~audience ] in
      return (`OK (id, clock))

(* Adding and removing from the group
   ================================== *)

let add_internal cid contacts groups = 
  if contacts = [] || groups = [] then return Cqrs.Clock.empty else
    Store.append [ Events.added ~cid ~contacts ~groups ] 

let add_forced contacts groups = 
  add_internal None contacts groups

let with_moderator_rights cid groups f = 

  let  compute = GroupAccess.compute cid in 

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

let add cid contacts groups = 
  with_moderator_rights cid groups (fun () ->     
    let! at = add_internal cid contacts groups in 
    return (`OK at)) 
    
let remove cid contacts groups = 
  with_moderator_rights cid groups (fun () -> 

      let! at = 
	if contacts = [] || groups = [] then return Cqrs.Clock.empty else
	  Store.append [ Events.removed ~cid ~contacts ~groups ] in

      return (`OK at))    

(* Deleting the group 
   ================== *)
  
let delete cid id = 
  let! info = Cqrs.MapView.get View.info id in 
  match info with None -> return (`NotFound id) | Some info -> 

    let! access = GroupAccess.compute cid (info # audience) in
    
    if Set.mem `Admin access then 
      let! clock = Store.append [ Events.deleted ~cid ~id ] in
      return (`OK clock) 
    else if Set.mem `View access then
      return (`NeedAdmin id) 
    else
      return (`NotFound id) 
