(* © 2014 RunOrg *)

open Std

let create ?label ?id () = 
  let! id = match id with 
    | None -> return (Ok (I.gen ()))
    | Some id -> let gid = I.of_id (CustomId.to_id id) in
		 let! exists = Cqrs.SetView.exists View.exists gid in 
		 return (if exists then Bad id else Ok gid)
  in

  match id with 
  | Ok id -> let! clock = Store.append [ Events.created ~id ~label ] in
	     return (`OK (id, clock))
  | Bad id -> return (`AlreadyExists id)

let add contacts groups = 
  if contacts = [] || groups = [] then return Cqrs.Clock.empty else
    Store.append [ Events.added ~contacts ~groups ]
    
let remove contacts groups = 
  if contacts = [] || groups = [] then return Cqrs.Clock.empty else
    Store.append [ Events.removed ~contacts ~groups ]

let delete id = 
  let! clock = Store.append [ Events.deleted ~id ] in
  return clock 
