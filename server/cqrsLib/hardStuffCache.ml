(* © 2014 RunOrg *)

open Std

type ('key,'value) t = {
  kpack : 'key Pack.packer ;
  vpack : 'value Pack.packer ;
  vupack : 'value Pack.unpacker ;
  name : string ; 
  dbname : string ;
  mutable mutexes : ('key,Run.mutex) Map.t ;
}

let make name version key value run = 
  assert false

let get t k clock = 
  assert false
