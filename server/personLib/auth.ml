(* © 2014 RunOrg *)

open Std

let auth_persona audience assertion = 

  let respond clock info = 
    let! ctx = Run.context in 
    let! token = Token.create (`Person (ctx # db, info # id)) in
    let  token = Token.I.Assert.person token in 
    return (`OK (token, info, clock))
  in

  let! audiences = Db.persona_audience () in 
  let  allowed = List.exists (String.Url.equal audience) audiences in 
  if not allowed then return (`BadAudience audience) else

    let! email_opt = Persona.validate ~audience:(String.Url.to_string audience) assertion in 
    let  email_opt = Option.bind email_opt String.Label.of_string in
    match email_opt with None -> return `InvalidAssertion | Some email ->     
      let! id = Cqrs.MapView.get View.byEmail email in 
      let! info = Option.M.bind Queries.get id in
      match info with Some info -> respond Cqrs.Clock.empty info | None -> 
	let! id, clock = Commands.create_forced email in
	let  info = Queries.initial_short id email in
	respond clock info 
