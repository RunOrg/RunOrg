(* © 2013 RunOrg *)

open Std

include type module string

let compare = compare

let to_id = identity
let of_id = identity
let of_string = identity
let to_string = identity	
let str = identity

let sel id = "#"^id

let gen = 

  let _uniq_b = ref 0 in
  let _uniq_c = Unix.getpid () in
  let seq_cdb = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz" in

  let base62 seq n i = 
    let r = String.make n seq.[0] in
    let rec aux i k = 
      if i <> 0 then begin
	r.[k] <- seq.[i mod 62] ;
	aux (i / 62) (k - 1)
      end
    in aux i (n-1) ; r
  in

  fun () ->
    let a = int_of_float (Unix.time() -. 1384421204.0)
    and b = incr _uniq_b ; !_uniq_b mod 238328
    and c = _uniq_c
    in (base62 seq_cdb 5 a)^(base62 seq_cdb 3 b)^(base62 seq_cdb 3 c)
    
let length   = 11

module Phantom = struct

  type 'nature id  = t
  type t = [`Unknown] id

  let compare = compare

  let of_id = identity
  let to_id = identity

  let to_string = identity
  let of_string = identity

  let gen () = gen ()
  let decay id = id

  let to_json = to_json
  let of_json = of_json 
  let of_json_safe = of_json_safe
  let of_json_string_safe = of_json_string_safe
  let to_json_string = to_json_string

  let pack    = pack
  let unpack  = unpack

end
  
module type PHANTOM = sig

  type 'relation id

  val compare : 'relation id -> 'relation id -> int

  val of_id : t       -> [`Unknown] id
  val to_id : 'any id -> t

  include Fmt.FMT with type t = [`Unknown] id

  val gen : unit -> t

  val to_string : 'any id -> string
  val of_string : string -> t

  val decay : 'any id -> t

end
