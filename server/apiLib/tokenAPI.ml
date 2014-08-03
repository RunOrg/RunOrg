(* © 2014 RunOrg *)

open Std

let notFound tok = 
  `NotFound (!! "Token %S does not exist." (Token.I.to_string tok))

module Get = Endpoint.Get(struct

  module Arg = type module < token : Token.I.t > 
  module Out = type module <
    token : Token.I.t ;
    self  : PersonAPI.Short.t ;
  >  

  let path = "tokens/{token}"

  let response req arg = 
    let  token = arg # token in
    let! pid = Token.describe token in
    match pid with None -> return (notFound token) | Some pid -> 
      let! person = Person.get pid in 
      match person with None -> return (notFound token) | Some self ->
	return (`OK (Out.make ~self ~token))

end)

(* UNTESTED *)
module Delete = Endpoint.Delete(struct

  module Arg = type module < token : Token.I.t >
  module Out = type module < 
    token : Token.I.t ;
  >
  
  let path = "tokens/{token}"

  let response req arg = 
    let! response = Token.delete (arg # token) in
    return (match response with 
    | `NotFound id -> notFound id 
    | `OK id -> `OK (Out.make ~token:id))
  
end)
