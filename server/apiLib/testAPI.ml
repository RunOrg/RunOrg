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
	return (`Accepted (Out.make ~id:cid ~token ~at))

end)

(* Testing Unturing templates 
   ========================== *)

module TestUnturing = Endpoint.SPost(struct

  module Arg = type module unit
  module Post = type module <
    script : string ;
    inline : Json.t list ;
   ?input  : Json.t = Json.Object [] ;
   ?html   : bool = true ;
  >

  module Out = type module <
    result   : string ;
    size     : int ; 
    duration : float ;  
  >

  let path = "test/unturing"

  let syntax_error (token, line, col) = 
    let str = !! "Line %d, col %d: unexpected token %S" (line+1) (col+1) token in 
    `BadRequest str

  let response req () post = 
    if not Configuration.test then return bad_auth else
      match Unturing.compile (post # script) (post # inline) with 
      | `SyntaxError e -> return (syntax_error e) 
      | `OK script -> 

	let input = match post # input with 
	  | Json.Object l -> Map.of_list l 
	  | _ -> Map.empty in
	
	let start    = Unix.gettimeofday () in
	let result   = Unturing.template ~html:(post # html) script input in
	let duration = (Unix.gettimeofday () -. start) /. 1000. in 
	let size     = String.length result in 

	return (`OK (Out.make ~result ~size ~duration)) 

end)
