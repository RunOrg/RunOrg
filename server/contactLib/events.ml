(* © 2014 RunOrg *)

include type module 
    [ `Created of < id : I.t ; email : string >
    | `InfoUpdated of < 
	id : I.t ; 
        fullname : string option ; 
	lastname : string option ; 
	firstname : string option ; 
	gender : [`F|`M] option 
      >
    ]
