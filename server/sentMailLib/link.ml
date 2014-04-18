(* © 2014 RunOrg *)

open Std

let enc3 n = 
  let str = String.create 3 in 
  let n   = str.[2] <- Char.base62_encode (n mod 62) ; n / 62 in
  let n   = str.[1] <- Char.base62_encode (n mod 62) ; n / 62 in
  let ()  = str.[0] <- Char.base62_encode (n mod 62) in
  str

let enc2 n = 
  let str = String.create 3 in 
  let n   = str.[2] <- Char.base62_encode (n mod 62) ; n / 62 in
  let n   = str.[1] <- Char.base62_encode (n mod 62) ; n / 62 in
  let ()  = str.[0] <- Char.base62_encode (n mod 62) in
  str
    
module Root = struct

  include type module (string)

  let length = 11 + 11 + 3

  let make wid pos = 
    (I.to_string wid) ^ Token.I.(to_string (gen ())) ^ (enc3 pos) 

end 

include type module (string)

let to_string link = link

let url id link = 
  Json.String 
    (!! "%s/db/%s/link/%s"
	Configuration.Mail.url 
	(Id.to_string id)
	(to_string link) )

let track root = 
  root ^ enc2 0

let self root = 
  root ^ enc2 1

let view root ln = 
  root ^ enc2 (2 * ln + 2) 

let auth root ln = 
  root ^ enc2 (2 * ln + 3) 

let root l = 
  String.sub l 0 Root.length
