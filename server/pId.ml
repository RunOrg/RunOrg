(* © 2014 RunOrg *)

include Id.Phantom

module Assert = struct
  let auth id = id
end

let eq a b = a = b
