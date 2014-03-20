(* © 2014 RunOrg *)

open Std

module Create = Endpoint.Post(struct

  module Arg  = type module unit
  module Post = type module <
    hash     : Key.Hash.t ;
    key      : string ;
    encoding : [ `hex ] ;
  >

  module Out = type module <
    id : Key.I.t ;
    at : Cqrs.Clock.t ;
  >

  let path = "keys/create"

  let response req () post = 

    let key = match post # encoding with 
      | `hex -> String.decode_base36 (post # key) 
    in

    let! id, at = Key.create (req # client_ip) (post # hash) key in

    return (`Accepted (Out.make ~id ~at))

end)

