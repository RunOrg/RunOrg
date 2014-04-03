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
		 (post # owner) (post # audience) (post # custom) (post # fields) in
	       match id with 
	       | None -> return (`BadRequest "Identifier is already taken")
	       | Some id -> return (`Accepted (Out.make ~id ~at))

end)

(* Updating a form
   =============== *)

module Update = Endpoint.Put(struct

  module Arg = type module < id : Form.I.t >
  module Put = type module <
    ?label : String.Label.t option ;
    ?custom : Json.t = Json.Null ;
    ?owner : Form.Owner.t option ;
    ?fields : Field.t list option ;
    ?audience : Form.Audience.t option ;
  >

  module Out = type module <
    at : Cqrs.Clock.t 
  >

  let path = "forms/{id}"

  let response req arg put = 
    
    (* Special treatment to separate "null" fields from missing fields *)
    let label = match req # body with 
      | Some (`JSON (Json.Object obj)) when List.exists (fun (k,_) -> k = "label") obj -> Some (put # label)
      | _ -> None
    and custom = match req # body with 
      | Some (`JSON (Json.Object obj)) when List.exists (fun (k,_) -> k = "custom") obj -> Some (put # custom)
      | _ -> None
    and owner = put # owner and fields = put # fields and audience = put # audience in 

    let! result = Form.update ?label ?custom ?owner ?fields ?audience (arg # id) in

    match result with 
    | `OK at -> return (`Accepted (Out.make ~at))
    | `NoSuchForm id -> return (`NotFound (!! "Form '%s' does not exist." (Form.I.to_string id)))
    | `FormFilled id ->  return (`BadRequest (!! "Form '%s' is already filled." (Form.I.to_string id)))

end)
