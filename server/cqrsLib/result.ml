(* © 2013 RunOrg *)

open Std

let string r = 
  if Array.length r = 0 then None else
    if Array.length r.(0) = 0 then None else
      Some r.(0).(0)

let unpack r unpacker = 
  Option.map (Pack.of_string unpacker) (string r)
