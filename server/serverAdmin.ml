(* © 2013 RunOrg *)

open Std

(* Authentication 
   ============== *)

let auth_persona assertion = 
  let! email = Persona.validate ~audience:Configuration.admin_audience assertion in 
  match email with None -> return None | Some email -> 
    if not (List.mem email Configuration.admins) then return None else
      let! token = Token.create `ServerAdmin in 
      let  token = Token.I.Assert.server_admin token in 
      return (Some (token, email))

