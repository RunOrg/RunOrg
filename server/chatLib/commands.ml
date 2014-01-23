(* © 2014 RunOrg *)

open Std

let create contacts groups = 
  let  id = I.gen () in 
  let! clock = Store.append [ Events.chatCreated ~id ~contacts ~groups ] in
  return (id, clock) 

let createPM c1 c2 = 
  (* TODO : don't create duplicates *)
  let  c1, c2 = min c1 c2, max c1 c2 in
  let  id = I.gen () in 
  let! clock = Store.append [ Events.privateMessageCreated ~id ~who:(c1,c2) ] in
  return (id, clock) 

let delete id = 
  Store.append [ Events.deleted ~id ]

let post id author body = 
  let  mid = MI.gen () in 
  let! clock = Store.append [ Events.posted ~id ~mid ~author ~body ] in
  return (mid, clock) 
