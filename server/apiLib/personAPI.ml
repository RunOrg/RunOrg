(* © 2014 RunOrg *)

open Std

module Short = type module <
  id     : PId.t ;
  label  : String.Label.t ; 
  gender : [`F|`M] option ;
  pic    : string ; 
>

let bad_auth  = `Forbidden "Could not log in"

module Auth_Persona = Endpoint.Post(struct

  module Arg  = type module unit
  module Post = type module < assertion : string > 
  module Out = type module < 
    token : Token.I.t ; 
    self  : Short.t ; 
    at    : Cqrs.Clock.t ;
  >

  let path = "people/auth/persona"

  let response req () p = 
    let! result = Person.auth_persona (p # assertion) in 
    match result with None -> return bad_auth | Some (token, self, at) -> 
      let token = Token.I.decay token in 
      return (`Accepted (Out.make ~token ~self ~at))

end)

module Auth_Hmac = Endpoint.Post(struct

  module Arg = type module unit 
  module Post = type module <
    id      : PId.t ;
    expires : Time.t ;
    key     : Key.I.t ;
    proof   : string ;
  >

  module Out = type module <
    token : Token.I.t ;
    self  : Short.t ;
  >  

  module Error = type module <
    assertion : string ;
    debug     : string ;
    hash      : Key.Hash.t ;
  >

  let path = "people/auth/hmac"

  let response req () p = 
    match try Some (String.hex_decode (p # proof)) with _ -> None with 
      | None -> return (`BadRequest "Could not decode hexadecimal proof.")
      | Some uproof -> 

	let! ctx = Run.context in
	if ctx # time > p # expires then 
	  return (`BadRequest (!! "Current time (%s) is past expiration date" (Time.to_iso8601 (ctx # time))))
	else
	  
	  let  assertion = "auth:" ^ PId.to_string (p # id) ^ ":until:" ^ Time.to_iso8601 (p # expires) in
	  let! hmac = Key.hmac (p # key) assertion in 
	  
	  match hmac with 
	  | None -> 
	    return (`NotFound (!! "Key '%s' does not exist" (Key.I.to_string (p # key))))
	      
	  | Some (proof, hash, zeroproof) when proof <> uproof ->       
	    let json = Error.to_json (Error.make ~assertion 
					~debug:(String.hex_encode (Lazy.force zeroproof)) ~hash) in

	    return (`WithJSON (json, `Forbidden "Invalid proof"))
	      
	  | Some _ -> 
	    let! person_opt = Person.get (p # id) in 
	    match person_opt with 
	    | None -> 
	      return (`NotFound (!! "Person '%s' does not exist" (PId.to_string (p # id))))
		
	    | Some self -> 
	      let! token = Token.create (`Person (ctx # db, p # id)) in
	      return (`OK (Out.make ~self ~token))

end)

module Import = Endpoint.Post(struct

  module Arg = type module unit

  module Post = type module <
    email      : String.Label.t ;
   ?name       : String.Label.t option ; 
   ?givenName  : String.Label.t option ;
   ?familyName : String.Label.t option ; 
   ?gender     : [`F|`M] option ;
  > list

  module Out = type module <
    created   : PId.t list ;
    at        : Cqrs.Clock.t ;
  >

  let path = "people/import"

  let response req () post = 

    let! created = List.M.map begin fun profile ->
      Person.create 
	?name:(profile # name)
	?givenName:(profile # givenName)
	?familyName:(profile # familyName)
	?gender:(profile # gender)
	(profile # email) 
    end post in 

    let out = Out.make 
      ~at:(List.fold_left (fun acc (_,clock) -> Cqrs.Clock.merge acc clock) Cqrs.Clock.empty created)
      ~created:(List.map fst created) 
    in

    return (`Accepted out) 
			      
end)

module Get = Endpoint.Get(struct

  module Arg = type module < id : PId.t >
  module Out = Short

  let path = "people/{id}"

  let response req args = 
    let! person_opt = Person.get (args # id) in 
    match person_opt with Some person -> return (`OK person) | None ->
      return (`NotFound (!! "Person '%s' does not exist" (PId.to_string (args # id))))
    
end)

module All = Endpoint.Get(struct

  module Arg = type module unit
  module Out = type module <
    list  : Short.t list ; 
    count : int 
  >

  let path = "people"

  let response req () = 
    let limit = Option.default 1000 (req # limit) in
    let offset = Option.default 0 (req # offset) in
    let! list, count = Person.all ~limit ~offset in
    return (`OK (Out.make ~list ~count))

end)

module Search = Endpoint.Get(struct

  module Arg = type module < q : string >
  module Out = type module <
    list  : Short.t list ; 
  >

  let path = "people/search"

  let response req arg = 
    let limit  = Option.default 10 (req # limit) in
    let prefix = arg # q in 
    let! list = Person.search ~limit prefix in
    return (`OK (Out.make ~list))

end)
