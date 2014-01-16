(* © 2013 RunOrg *)

open Std

include Endpoint.SGet(struct

  module Arg = type module unit
  module Out = type module < version : string >

  let path = "version" 

  let response req () = 
    return (`OK (Out.make ~version:RunorgVersion.version_string))

end)
