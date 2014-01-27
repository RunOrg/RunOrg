(* © 2014 RunOrg *)

open Std

include type module 
    [ `Created of < id : CId.t ; email : String.Label.t >
    | `InfoUpdated of < 
	id : CId.t ; 
        fullname : String.Label.t option ; 
	lastname : String.Label.t option ; 
	firstname : String.Label.t option ; 
	gender : [`F|`M] option 
      >
    ]
