(* © 2014 RunOrg *)

include type module 
    [ `Created of < id : CId.t ; email : string >
    | `InfoUpdated of < 
	id : CId.t ; 
        fullname : string option ; 
	lastname : string option ; 
	firstname : string option ; 
	gender : [`F|`M] option 
      >
    ]
