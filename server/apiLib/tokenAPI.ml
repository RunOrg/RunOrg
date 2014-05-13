(* © 2014 RunOrg *)

open Std

module Get = Endpoint.Get(struct

  module Arg = type module < token : Token.I.t > 
  module Out = type module <
    token : Token.I.t ;
    self  : PersonAPI.Short.t ;
  >  

  let path = "token/{token}"

  let notFound tok = 
    `NotFound (!! "Token %S does not exist." (Token.I.to_string tok))

  let response req arg = 
    let  token = arg # token in
    let! pid = Token.describe token in
    match pid with None -> return (notFound token) | Some pid -> 
      let! person = Person.get pid in 
      match person with None -> return (notFound token) | Some self ->
	return (`OK (Out.make ~self ~token))

end)

