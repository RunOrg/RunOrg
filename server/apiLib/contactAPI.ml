(* © 2014 RunOrg *)

open Std

module Short = type module <
  id     : CId.t ;
  name   : String.Label.t ; 
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

  let path = "contacts/auth/persona"

  let response req () p = 
    let! result = Contact.auth_persona (p # assertion) in 
    match result with None -> return bad_auth | Some (token, self, at) -> 
      let token = Token.I.decay token in 
      return (`Accepted (Out.make ~token ~self ~at))

end)

module Import = Endpoint.Post(struct

  module Arg = type module unit

  module Post = type module <
    email     : String.Label.t ;
   ?fullname  : String.Label.t option ; 
   ?firstname : String.Label.t option ;
   ?lastname  : String.Label.t option ; 
   ?gender    : [`F|`M] option ;
  > list

  module Out = type module <
    created   : CId.t list ;
    at        : Cqrs.Clock.t ;
  >

  let path = "contacts/import"

  let response req () post = 

    let! created = List.M.map begin fun profile ->
      Contact.create 
	?fullname:(profile#fullname)
	?firstname:(profile#firstname)
	?lastname:(profile#lastname)
	?gender:(profile#gender)
	(profile # email) 
    end post in 

    let out = Out.make 
      ~at:(List.fold_left (fun acc (_,clock) -> Cqrs.Clock.merge acc clock) Cqrs.Clock.empty created)
      ~created:(List.map fst created) 
    in

    return (`Accepted out) 
			      
end)

module Get = Endpoint.Get(struct

  module Arg = type module < cid : CId.t >
  module Out = Short

  let path = "contacts/{cid}"

  let response req args = 
    let! contact_opt = Contact.get (args # cid) in 
    match contact_opt with Some contact -> return (`OK contact) | None ->
      return (`NotFound (!! "Contact '%s' does not exist" (CId.to_string (args # cid))))
    
end)

module All = Endpoint.Get(struct

  module Arg = type module unit
  module Out = type module <
    list  : Short.t list ; 
    count : int 
  >

  let path = "contacts"

  let response req () = 
    let limit = Option.default 1000 (req # limit) in
    let offset = Option.default 0 (req # offset) in
    let! list, count = Contact.all ~limit ~offset in
    return (`OK (Out.make ~list ~count))

end)

module Search = Endpoint.Get(struct

  module Arg = type module < q : string >
  module Out = type module <
    list  : Short.t list ; 
  >

  let path = "contacts/search"

  let response req arg = 
    let limit  = Option.default 10 (req # limit) in
    let prefix = arg # q in 
    let! list = Contact.search ~limit prefix in
    return (`OK (Out.make ~list))

end)
