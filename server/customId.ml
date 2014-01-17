(* © 2014 RunOrg *)

type t = string
let to_id = Id.of_string

(* Validation 
   ========== *)

let char_is_alphanumeric = function 
  | 'a' .. 'z'
  | 'A' .. 'Z' 
  | '0' .. '9' -> true
  | _ -> false

let is_valid str = 
  let n = String.length str in 
  if n = 0 || n > 10 then false else 
    let ok = ref true and i = ref 0 in
    while !ok && !i < n do ok := char_is_alphanumeric str.[!i] ; incr i done ;
    !ok 

let validate str = 
  if is_valid str then Some str else None
