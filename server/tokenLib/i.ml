(* © 2014 RunOrg *)

open Std

include Id.Phantom

module Assert = struct
  let server_admin id = id
  let contact id = id 
end

(* We cannot use the standard generation function here, because its output is 
   predictable. Instead, we generate an HMAC of a standard identifier, using the
   configured token key. This HMAC is converted to base62 and truncated. 
   
   For 1 000 000 simultaneous sessions, there is a 3e-6 probability of collision
   (because the 11-character base62 identifier is generated from a random 
   64-bit value, with a single base62 character dropped). *)
let gen () = 
  let unsafe_token_id = gen () in 
  let hmac = Sha1.hmac Configuration.token_key (to_string unsafe_token_id) in
  let b62 = String.base62_encode hmac in 
  of_string (String.sub b62 0 Id.length)

