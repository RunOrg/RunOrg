(* © 2014 RunOrg *)

include Id.Phantom

let of_custom id = 
  of_id (CustomId.to_id id) 
