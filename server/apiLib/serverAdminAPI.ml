(* © 2013 RunOrg *)

open Std

let forbidden = `Forbidden "Token is not a server administrator"
let bad_auth  = `Forbidden "Could not log in as server administrator"

(* Administration UI 
   ================= *)

let () = 
  Endpoint.static "admin" "text/html" "static/admin/index.html" ;
  Endpoint.static "admin/script.js" "text/javascript" "_assets/admin/all.js" ;
  Endpoint.static "admin/en.js" "text/javascript" "_assets/admin/en.js" ;
  Endpoint.static "admin/style.css" "text/css" "_assets/admin/all.css" ;
  Endpoint.static "admin/logo.png" "image/png" "static/admin/logo-runorg-50x50.png"

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

  module Admin = type module < email : string ; fromConfig : bool >

  module Arg = type module < token : Token.I.t >
  module Out = type module < admins : Admin.t list >

  let path = "admin/all" 

  let response req a = 
    let! token = Token.is_server_admin (a # token) in
    match token with None -> return forbidden | Some token -> 
      let! admins = ServerAdmin.all token in 
      return (`OK (Out.make ~admins))

end)

(* Create a new database 
   ===================== *)

module DbCreate = Endpoint.Post(struct

  module Arg  = type module < token : Token.I.t >
  module Post = type module < label : string >
  module Out  = type module < id : Id.t ; at : Cqrs.Clock.t >

  let path = "db/create"

  let response req a p = 
    let! token = Token.is_server_admin (a # token) in
    match token with None -> return forbidden | Some token -> 
      let! id, at = Db.create token (p # label) in
      return (`Accepted (Out.make ~id ~at))

end)
