(* © 2014 RunOrg *)

open Std

module Import = Endpoint.Post(struct

  module Arg = type module unit

  module Post = type module <
    email     : string ;
   ?fullname  : string option ; 
   ?firstname : string option ;
   ?lastname  : string option ; 
   ?gender    : [`F|`M] option ;
  > list

  module Out = type module <
    created   : CId.t list ;
    at        : Cqrs.Clock.t ;
  >

  let path = "contact/import"

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
