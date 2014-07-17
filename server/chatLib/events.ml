(* © 2014 RunOrg *)

open Std

include type module 
    [ `ChatCreated of < 
	id       : I.t ; 
        pid      : PId.t option ; 
	subject  : String.Label.t option ;
	audience : ChatAccess.Audience.t ; 
      >
    | `ChatDeleted of < 
	id  : I.t ;
        pid : PId.t option ; 
      >
    | `PostCreated of < 
	id     : I.t ;         
        post   : PostI.t ; 
	author : PId.t ; 
	body   : String.Rich.t ;
      >
    | `PostDeleted of < 
	id   : I.t ; 
        pid  : PId.t option ; 
        post : PostI.t ; 
      > 
    ]
