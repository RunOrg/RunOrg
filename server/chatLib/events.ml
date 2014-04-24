(* © 2014 RunOrg *)

open Std

include type module 
    [ `PrivateMessageCreated of < id : I.t ; who : PId.t * PId.t >
    | `ChatCreated of < 
	id : I.t ; 
        people : PId.t list ; 
	groups : GId.t list ; 
	subject : String.Label.t option ;
      >
    | `ChatDeleted of < id : I.t >
    | `ItemPosted of < id : I.t ; item : MI.t ; author : PId.t ; body : String.Rich.t >
    | `ItemDeleted of < id : I.t ; item : MI.t > 
    | `PublicChatCreated of <
	id : I.t ;
        subject : String.Label.t option ;
      >
    ]
