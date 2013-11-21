(* © 2013 RunOrg *)

open Std

let forbidden = `Forbidden "Token is not a server administrator"
let bad_auth  = `Forbidden "Could not log in as server administrator"

(* Administration UI 
   ================= *)

let () = 
  Endpoint.static "admin" "text/html" "admin/index.html" ;
  Endpoint.static "admin/script.js" "text/javascript" "admin/script.js" ;
  Endpoint.static "admin/style.css" "text/css" "admin/style.css" 

(* Authenticate as a server administrator 
   ====================================== *)

module Auth_Persona = Endpoint.Post(struct

  module Arg  = type module unit
  module Post = type module < assertion : string >
  module Out  = type module < token : Token.I.t ; email : string >

  let path = "admin/auth/persona"

  let response req () p = 
    let! result = ServerAdmin.auth_persona (p # assertion) in
    match result with None -> return bad_auth | Some (token, email) ->
      let token = Token.I.decay token in 
      return (`OK (Out.make ~token ~email)) 

end)

(* List of all registered administrators 
   ===================================== *)

module All = Endpoint.Get(struct

  module Admin = type module < email : string >
  let wrap email = Admin.make ~email

  module Arg = type module < token : Token.I.t >
  module Out = type module < admins : Admin.t list >

  let path = "admin/all" 

  let response req a = 
    let  list = Configuration.admins in 
    let! token = Token.is_server_admin (a # token) in
    match token with None -> return forbidden | Some token -> 
      return (`OK (Out.make ~admins:(List.map wrap list)))

end)
