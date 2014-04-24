(* © 2014 RunOrg *)

open Std

include type module 
    [ `Created of < id : PId.t ; email : String.Label.t >
    | `InfoUpdated of < 
	id : PId.t ; 
        name : String.Label.t option ; 
	familyName : String.Label.t option ; 
	givenName : String.Label.t option ; 
	gender : [`F|`M] option 
      >
    ]
