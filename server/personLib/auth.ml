(* © 2014 RunOrg *)

open Std

let auth_persona assertion = 

  let respond clock info = 
    let! ctx = Run.context in 
    let! token = Token.create (`Person (ctx # db, info # id)) in
    let  token = Token.I.Assert.person token in 
    return (Some (token, info, clock))
  in

  let! audience  = Db.persona_audience () in 
  let! email_opt = Persona.validate ~audience assertion in 
  let  email_opt = Option.bind email_opt String.Label.of_string in
  match email_opt with None -> return None | Some email ->     
    let! id = Cqrs.MapView.get View.byEmail email in 
    let! info = Option.M.bind Queries.get id in
    match info with Some info -> respond Cqrs.Clock.empty info | None -> 
      let! id, clock = Commands.create_forced email in
      let  info = Queries.initial_short id email in
      respond clock info 
