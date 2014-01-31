(* © 2014 RunOrg *)

open Std 

(* Testing (or documentation) UI
   ============================= *)

let () = 
  if Configuration.test then begin

    (* Static entry point. *)
    Endpoint.static "docs" "text/html" "static/testUI/index.html" ;

    (* Static assets generated though the JS app compiler. *)
    Endpoint.static "docs/script.js" "text/javascript" "_assets/testUI/all.js" ;
    Endpoint.static "docs/style.css" "text/css" "_assets/testUI/all.css" ;

    (* Directory of all tests, from the test module. *)
    Endpoint.json "docs/all.json" Json.(of_assoc Test.all) ;
    List.iter (fun (path,_) -> Endpoint.static ("docs/" ^ path) "text/plain" ("test/" ^ path)) Test.all ;

  end 

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
  module Post = type module < ?email : string = "test@runorg.com" >
  module Out = type module < token : Token.I.t ; at : Cqrs.Clock.t >

  let path = "test/auth"

  let response req () post = 
    if not Configuration.test then return bad_auth else
      match String.Label.of_string (post # email) with None -> return bad_email | Some email -> 
	let! ctx = Run.context in 
	let! cid, at = Contact.create email in
	let  owner = `Contact (ctx # db, cid) in
	let! token = Token.create owner in
	return (`OK (Out.make ~token ~at))

end)
