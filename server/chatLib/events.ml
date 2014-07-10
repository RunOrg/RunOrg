(* © 2014 RunOrg *)

open Std

include type module 
    [ `ChatCreated of < 
	id : I.t ; 
        people : PId.t list ; 
	groups : GId.t list ; 
	subject : String.Label.t option ;
      >
    | `ChatDeleted of < id : I.t >
    | `PostCreated of < 
	id : I.t ; 
        post : PostI.t ; 
	author : PId.t ; 
	body : String.Rich.t ;
      >
    | `PostDeleted of < id : I.t ; post : PostI.t > 
    | `PublicChatCreated of <
	id : I.t ;
        subject : String.Label.t option ;
      >
    ]
