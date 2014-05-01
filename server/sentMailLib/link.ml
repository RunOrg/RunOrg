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

let dec s = 
  let n = String.length s in 
  let rec dec acc i = if i >= n then acc else dec (Char.base62_decode s.[i] + 62 * acc) (i+1) in
  dec 0 0

(* Link root
   ========= *)

module Root = struct

  let length = 11 + 11 + 3

  let to_string (wid,tid,pos) = 
    (I.to_string wid) ^ Token.I.(to_string (gen ())) ^ (enc3 pos) 

  let of_string s = 
      if String.length s <> length then 
	raise (Json.error "Not a valid e-mail token.")
      else
	try I.of_string (String.sub s 0 11), 
	    Token.I.of_string (String.sub s 11 11), 
	    dec (String.sub s 22 3)
	with _ -> raise (Json.error "Not a valid e-mail token.")

  include Fmt.Map(struct 

    module Inner = type module (string)
    type t = I.t * Token.I.t * int

    let from_inner = of_string
    let to_inner = to_string

  end)

  let make wid pos = 
    (wid, Token.I.gen (), pos)     

end 

(* Complete link
   ============= *)

let length = Root.length + 2

let to_string (root,what) =
  Root.to_string root ^ enc2 (match what with 
  | `Track   -> 0
  | `Self    -> 1
  | `Auth  i -> 2 + 2 * i
  | `View  i -> 3 + 2 * i)

include Fmt.Map(struct

  module Inner = type module (string)
  type t = Root.t * [ `Track | `Self | `Auth of int | `View of int ]

  let from_inner s = 
    try let n = dec (String.sub s Root.length 2) in
	Root.of_string (String.sub s 0 Root.length), 
	(match n with 
	| 0 -> `Track 
	| 1 -> `Self 
	| n when n mod 2 = 0 -> `Auth ((n - 2) / 2)
	| n -> `View ((n - 3) / 2))
    with _ -> raise (Json.error "Not a valid e-mail token.")

  let to_inner = to_string

end)

let url id link = 
  Json.String 
    (!! "%s/db/%s/link/%s"
	Configuration.Mail.url 
	(Id.to_string id)
	(to_string link))

let track root = root, `Track
let self  root = root, `Self
let view  root ln = root, `View ln
let auth  root ln = root, `Auth ln 
let root (root,_) = root
let what (_,what) = what
