(* © 2014 RunOrg *)

open Std

(* Who is allowed to create new groups ? *)
let create_audience = Audience.admin 

let create ?label ?id cid = 

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

      let! clock = Store.append [ Events.created ~cid ~id ~label ] in
      return (`OK (id, clock))

let add contacts groups = 
  if contacts = [] || groups = [] then return Cqrs.Clock.empty else
    Store.append [ Events.added ~cid:None ~contacts ~groups ]
    
let remove contacts groups = 
  if contacts = [] || groups = [] then return Cqrs.Clock.empty else
    Store.append [ Events.removed ~cid:None ~contacts ~groups ]

let delete id = 
  let! clock = Store.append [ Events.deleted ~cid:None ~id ] in
  return clock 
