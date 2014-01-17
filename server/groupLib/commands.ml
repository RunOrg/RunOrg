(* © 2014 RunOrg *)

open Std

let create ?label ?id () = 
  let  id = match id with None -> I.gen () | Some id -> I.of_id (CustomId.to_id id) in
  let! clock = Store.append [ Events.created ~id ~label ] in
  return (id, clock) 
    
