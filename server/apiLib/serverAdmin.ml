(* © 2013 RunOrg *)

open Std

include Endpoint.Get(struct

  module Arg = type module unit
  module Out = type module < admins : < email : string > list >

  let path = "admin/all" 

  let wrap email = object 
    method email = email 
  end 

  let response req () = 
    let list = Configuration.admins in 
    return (`OK (Out.make ~admins:(List.map wrap list)))

end)
