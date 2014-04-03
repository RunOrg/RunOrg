(* © 2014 RunOrg *)

open Std

(* Creating a form 
   =============== *)

module Create = Endpoint.Post(struct

  module Arg = type module unit
  module Post = type module <
    ?id : string option ;
    ?label : String.Label.t option ; 
    ?custom : Json.t = Json.Null ; 
     owner : Form.Owner.t ;
     fields : Field.t list ;
     audience : Form.Audience.t ; 
  > 

  module Out = type module <
    id : Form.I.t ;
    at : Cqrs.Clock.t ;
  >

  let path = "forms/create"

  let response req () post = 
    match Option.bind (post # id) CustomId.validate, post # id with 
    | None, Some id -> return (`BadRequest (!! "%S is not a valid identifier" id))
    | id, _ -> let! id, at = Form.create ?id ?label:(post # label) 
		 (post # owner) (post # custom) (post # fields) in
	       match id with 
	       | None -> return (`BadRequest "Identifier is already taken")
	       | Some id -> return (`Accepted (Out.make ~id ~at))

end)
