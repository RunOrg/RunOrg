(* © 2014 RunOrg *)

open Std

let create ?fullname ?firstname ?lastname ?gender email = 
  let! id = Cqrs.MapView.get View.byEmail email in 
  match id with Some id -> return (id, Cqrs.Clock.empty) | None -> 

    let  id = I.gen () in 

    let  update = 
      if fullname <> None || lastname <> None || firstname <> None || gender <> None 
      then [ Events.infoUpdated ~id ~firstname ~lastname ~fullname ~gender ]
      else []
    in

    let  events = (Events.created ~id ~email) :: update in 

    let! clock = Store.append events in
    return (id, clock) 

