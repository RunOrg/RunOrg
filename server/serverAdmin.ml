(* © 2013 RunOrg *)

open Std

(* Authentication 
   ============== *)

let auth_persona assertion = 
  let! email = Persona.validate ~audience:Configuration.Audience.admin assertion in 
  match email with None -> return None | Some email -> 
    if not (List.mem email Configuration.admins) then return None else
      let! token = Token.create `ServerAdmin in 
      let  token = Token.I.Assert.server_admin token in 
      return (Some (token, email))

let auth_test () = 
  if Configuration.test then 
    let  email = match Configuration.admins with [] -> "vnicollet@runorg.com" | h :: _ -> h in
    let! token = Token.create `ServerAdmin in 
    let  token = Token.I.Assert.server_admin token in 
    return (Some (token, email))
  else
    return None

(* Listing all server administrators
   ================================= *)

let all token = 
  return (List.map 
	    (fun email -> (object method email = email method fromConfig = true end))
	    Configuration.admins)
