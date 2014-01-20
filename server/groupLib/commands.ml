(* © 2014 RunOrg *)

open Std

let create ?label ?id () = 
  let  id = match id with None -> I.gen () | Some id -> I.of_id (CustomId.to_id id) in
  let! clock = Store.append [ Events.created ~id ~label ] in
  return (id, clock) 

let add contacts groups = 
  if contacts = [] || groups = [] then return Cqrs.Clock.empty else
    Store.append [ Events.added ~contacts ~groups ]
    
let remove contacts groups = 
  if contacts = [] || groups = [] then return Cqrs.Clock.empty else
    Store.append [ Events.removed ~contacts ~groups ]

let delete id = 
  let! clock = Store.append [ Events.deleted ~id ] in
  return clock 
