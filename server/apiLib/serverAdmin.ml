(* © 2013 RunOrg *)

open Std

include Endpoint.Get(struct

  module Admin = type module < email : string >
  let wrap email = Admin.make ~email

  module Arg = type module unit
  module Out = type module < admins : Admin.t list >

  let path = "admin/all" 

  let response req () = 
    let list = Configuration.admins in 
    return (`OK (Out.make ~admins:(List.map wrap list)))

end)
