(* © 2014 RunOrg *)

open Std

let create ?fullname ?firstname ?lastname ?gender email = 
  let! id = Cqrs.MapView.get View.byEmail email in 
  match id with Some id -> return (id, Cqrs.Clock.empty) | None -> 

    let  id = I.gen () in 

    let  events = List.filter_map identity [
      Some (Events.created ~id ~email) ;
      Option.map (fun fullname -> Events.fullnameSet ~id ~fullname) fullname ;
      Option.map (fun lastname -> Events.lastnameSet ~id ~lastname) lastname ;
      Option.map (fun firstname -> Events.firstnameSet ~id ~firstname) firstname ;
      Option.map (fun gender -> Events.genderSet ~id ~gender) gender 
    ] in

    let! clock = Store.append events in
    return (id, clock) 

