(* © 2013 RunOrg *)

open Std

let string r = 
  if Array.length r = 0 then None else
    if Array.length r.(0) = 0 then None else
      Some r.(0).(0)

let bytes r = 
  Option.map Postgresql.unescape_bytea (string r)

let unpack r unpacker = 
  Option.map (Pack.of_string unpacker) (bytes r)

let int r = 
  Option.map int_of_string (string r)
