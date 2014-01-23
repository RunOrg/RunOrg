(* © 2014 RunOrg *)

include type module 
    [ `PrivateMessageCreated of < id : I.t ; who : CId.t * CId.t >
    | `ChatCreated of < id : I.t ; contacts : CId.t list ; groups : Group.I.t list >
    | `ChatDeleted of < id : I.t >
    | `ItemPosted of < id : I.t ; item : MI.t ; author : CId.t ; body : string >
    | `ItemDeleted of < id : I.t ; item : MI.t > 
    ]
