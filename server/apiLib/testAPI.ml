(* © 2014 RunOrg *)

open Std 

(* Creating a test token
   ===================== *)

let bad_auth  = `Forbidden "Test mode is disabled"
let bad_email = `BadRequest "Provided e-mail was invalid"

module AuthServerAdmin = Endpoint.SPost(struct

  module Arg = type module unit
  module Post = type module unit
  module Out = type module < token : Token.I.t ; email : string >

  let path = "test/auth"

  let response req () () = 
    let! result = ServerAdmin.auth_test () in
    match result with None -> return bad_auth | Some (token, email) ->
      let token = Token.I.decay token in 
      return (`OK (Out.make ~token ~email)) 


end)

module AuthDb = Endpoint.Post(struct

  module Arg = type module unit
  module Post = type module < 
    ?email : string = "test@runorg.com" ;
    ?admin : bool = true ; 
  >
  module Out = type module < token : Token.I.t ; at : Cqrs.Clock.t ; id : CId.t >

  let path = "test/auth"

  let response req () post = 
    if not Configuration.test then return bad_auth else
      match String.Label.of_string (post # email) with None -> return bad_email | Some email -> 
	let! ctx = Run.context in 
	let! cid, at = Contact.create email in
	let  owner = `Contact (ctx # db, cid) in
	let! at = 
	  if post # admin then let! at' = Group.add_forced [cid] [GId.admin] in
			       return (Cqrs.Clock.merge at at')
	  else return at in
	let! token = Token.create owner in
	return (`OK (Out.make ~id:cid ~token ~at))

end)
