(* © 2014 RunOrg *)

open Std

include type module 
    [ `PrivateMessageCreated of < id : I.t ; who : CId.t * CId.t >
    | `ChatCreated of < 
	id : I.t ; 
        contacts : CId.t list ; 
	groups : Group.I.t list ; 
	subject : String.Label.t option ;
      >
    | `ChatDeleted of < id : I.t >
    | `ItemPosted of < id : I.t ; item : MI.t ; author : CId.t ; body : String.Rich.t >
    | `ItemDeleted of < id : I.t ; item : MI.t > 
    ]
