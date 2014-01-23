(* © 2014 RunOrg *)

include type module 
    [ `PrivateMessageCreated of < id : I.t ; who : CId.t * CId.t >
    | `ChatCreated of < id : I.t ; contacts : CId.t list ; groups : Group.I.t list >
    | `Deleted of < id : I.t >
    ]
