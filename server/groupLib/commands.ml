(* © 2014 RunOrg *)

open Std

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

let add cid contacts groups = 
  if contacts = [] || groups = [] then return Cqrs.Clock.empty else
    Store.append [ Events.added ~cid ~contacts ~groups ]

let add_forced contacts groups = 
  add None contacts groups 
    
let remove cid contacts groups = 
  if contacts = [] || groups = [] then return Cqrs.Clock.empty else
    Store.append [ Events.removed ~cid ~contacts ~groups ]

let delete cid id = 
  let! info = Cqrs.MapView.get View.info id in 
  match info with None -> return (`NotFound id) | Some info -> 

    let! access = GroupAccess.compute cid (info # audience) in
    
    if Set.mem `Admin access then 
      let! clock = Store.append [ Events.deleted ~cid ~id ] in
      return (`OK clock) 
    else
      return (`NeedAdmin id) 
