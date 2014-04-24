(* © 2014 RunOrg *)

open Std

let create ?name ?givenName ?familyName ?gender email = 
  let! id = Cqrs.MapView.get View.byEmail email in 
  match id with Some id -> return (id, Cqrs.Clock.empty) | None -> 

    let  id = PId.gen () in 

    let  update = 
      if name <> None || givenName <> None || familyName <> None || gender <> None 
      then [ Events.infoUpdated ~id ~familyName ~givenName ~name ~gender ]
      else []
    in

    let  events = (Events.created ~id ~email) :: update in 

    let! clock = Store.append events in
    return (id, clock) 
