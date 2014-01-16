(* © 2014 RunOrg *)

include type module 
    [ `Created of < id : I.t ; email : string >
    | `FullnameSet of < id : I.t ; fullname : string >
    | `LastnameSet of < id : I.t ; lastname : string >
    | `FirstnameSet of < id : I.t ; firstname : string >
    | `GenderSet of < id : I.t ; gender : [`F|`M] >
    ]
