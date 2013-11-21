(* © 2013 RunOrg *)

open Std

let forbidden = `Forbidden "Token is not a server administrator"

(* List of all registered administrators 
   ===================================== *)

include Endpoint.Get(struct

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
