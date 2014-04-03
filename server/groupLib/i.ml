(* © 2014 RunOrg *)

include Id.Phantom

let is_admin id = to_string id = "admin"

let admin = of_string "admin"
