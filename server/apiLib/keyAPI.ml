(* © 2014 RunOrg *)

open Std

(* Creating a new key
   ================== *)

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

(* Listing available keys 
   ====================== *)

module Info = type module <
  id      : Key.I.t ;
  hash    : Key.Hash.t ;
  created : Time.t ; 
  enabled : bool ;
  from_ip : string ;
>

module List = Endpoint.Get(struct

  module Arg = type module unit
  module Out = type module <
    list  : Info.t list ;
    count : int ;
  >

  let path = "keys"

  let response req () = 
    let  limit = Option.default 1000 (req # limit) in
    let  offset = Option.default 0 (req # offset) in
    let! list, count = Key.list ~limit ~offset in 
    let  list = List.map (fun info -> Info.make
      ~id:(info # id) ~hash:(info # hash) ~created:(info # time) ~enabled:(info # enabled)
      ~from_ip:(IpAddress.to_string (info # ip))) list in
    return (`OK ( Out.make ~list ~count)) 

end)
