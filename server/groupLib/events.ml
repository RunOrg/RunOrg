(* © 2014 RunOrg *)

include type module 
    [ `Created of < id : I.t ; label : string option > 
    | `Deleted of < id : I.t >
    ]
