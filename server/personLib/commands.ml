(* © 2014 RunOrg *)

open Std

let create_forced ?name ?givenName ?familyName ?gender email = 
  let! id = Cqrs.MapView.get View.byEmail email in 
  match id with Some id -> return (id, Cqrs.Clock.empty) | None -> 

    let  id = PId.gen () in 

    let  update = 
      if name <> None || givenName <> None || familyName <> None || gender <> None 
      then [ Events.infoCreated ~id ~familyName ~givenName ~name ~gender ]
      else []
    in

    let  events = (Events.created ~id ~email) :: update in 

    let! clock = Store.append events in
    return (id, clock) 

type 'ctx creator = 
  ?name:String.Label.t -> 
  ?givenName:String.Label.t -> 
  ?familyName:String.Label.t -> 
  ?gender:[`F|`M] -> 
  String.Label.t -> ('ctx, PId.t * Cqrs.Clock.t) Run.t

(* Who is allowed to import contacts ? *)
let import_audience = Audience.admin 

let import pid = 
  
  let! allowed = Audience.is_member pid import_audience in 
  if not allowed then 
    let! ctx = Run.context in 
    return (`NeedAccess (ctx # db))
  else
    return (`OK create_forced)
  
(* Updating people's profiles
   ========================== *)

(* Who is allowed to update contacts ? *)
let update_audience = Audience.admin 

let update pid ~name ~givenName ~familyName ~gender ~email who = 
  
  let! allowed = 
    if pid = Some who then return true else
      Audience.is_member pid update_audience in
  if not allowed then
    let! ctx = Run.context in 
    return (`NeedAccess (ctx # db))
  else
    
    if name <> `Keep || givenName <> `Keep || familyName <> `Keep || gender <> `Keep || email <> `Keep then
      return (`OK Cqrs.Clock.empty)
    else

      let! clock = Store.append [
	Events.infoUpdated ~id:who ~name ~givenName ~familyName ~gender ~email 
      ] in
      
      return (`OK clock) 
