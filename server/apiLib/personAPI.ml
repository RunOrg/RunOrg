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
    imported  : PId.t list ;
    at        : Cqrs.Clock.t ;
  >

  let path = "people/import"

  let needAccess id = 
    `Forbidden (!! "You may not import people into database %S." (Id.to_string id))

  let response req () post = 

    let! create = Person.import (req # as_) in
    match create with `NeedAccess id -> return (needAccess id) | `OK create -> 

      let! imported = List.M.map begin fun profile ->
	create 
	  ?name:(profile # name)
	  ?givenName:(profile # givenName)
	  ?familyName:(profile # familyName)
	  ?gender:(profile # gender)
	  (profile # email) 
      end post in 
      
      let out = Out.make 
	~at:(List.fold_left (fun acc (_,clock) -> Cqrs.Clock.merge acc clock) Cqrs.Clock.empty imported)
	~imported:(List.map fst imported) 
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

(* UNTESTED *)
module Update = Endpoint.Put(struct
    
  module Arg = type module < id : PId.t >
  module Put = type module <
    ?name : String.Label.t option ;
    ?givenName : String.Label.t option ;
    ?familyName : String.Label.t option ;
    ?gender : [`M|`F] option ;
    ?email : String.Label.t option ;
  >

  module Out = type module < at : Cqrs.Clock.t >

  let path = "people/{id}"

  let needAccess id = 
    `Forbidden (!! "You may not update other people's profiles in database %S." (Id.to_string id))

  let response req args (put:Put.t) = 
    let! result = Person.update (req # as_) 
      ~name:(Change.of_field "name" (req # body) (put # name))
      ~givenName:(Change.of_field "givenName" (req # body) (put # givenName))
      ~familyName:(Change.of_field "familyName" (req # body) (put # familyName))
      ~gender:(Change.of_field "gender" (req # body) (put # gender))
      ~email:(Change.of_option (put # email))
      (args # id) in
    match result with 
    | `OK at -> return (`OK (Out.make ~at))
    | `NotFound id -> return (`NotFound (!! "Person '%s' does not exist" (PId.to_string id)))
    | `NeedAccess db -> return (needAccess db)

end)

let needAllAccess id = 
  `Forbidden (!! "Not allowed to list people in database '%s'." (Id.to_string id)) 

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
    let! result = Person.all (req # as_) ~limit ~offset in
    match result with 
    | `NeedAccess    id -> return (needAllAccess id)
    | `OK (list, count) ->  return (`OK (Out.make ~list ~count))

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
    let! result = Person.search (req # as_) ~limit prefix in
    match result with 
    | `NeedAccess id -> return (needAllAccess id)
    | `OK       list -> return (`OK (Out.make ~list))

end)
