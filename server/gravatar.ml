(* © 2014 RunOrg *)

let pic_of_email email = 
  let md5 = Digest.(to_hex (string String.(lowercase email))) in
  "https://www.gravatar.com/avatar/" ^ md5 ^ "?d=identicon"
