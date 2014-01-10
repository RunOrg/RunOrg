(* © 2014 RunOrg *)

open Std

let create email = 
  let! id = Cqrs.MapView.get View.byEmail email in 
  match id with Some id -> return (id, Cqrs.Clock.empty) | None -> 
    let  id = I.gen () in 
    let! clock = Store.append [ Events.contactCreated ~id ~email ] in
    return (id, clock) 

