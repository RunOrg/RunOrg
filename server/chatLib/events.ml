(* © 2014 RunOrg *)

open Std

include type module 
    [ `ChatCreated of < 
	id       : I.t ; 
        pid      : PId.t option ; 
	subject  : String.Label.t option ;
	custom   : Json.t ;
	audience : ChatAccess.Audience.t ; 
      >
    | `ChatUpdated of <
	id       : I.t ;
        pid      : PId.t option ;
	subject  : [ `Keep | `Set of String.Label.t option ] ;
	custom   : [ `Keep | `Set of Json.t ] ;
	audience : [ `Keep | `Set of ChatAccess.Audience.t ] ;
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
	custom : Json.t ; 
	parent : PostI.t option ; 
      >
    | `PostDeleted of < 
	id   : I.t ; 
        pid  : PId.t option ; 
        post : PostI.t ; 
      > 
    | `TrackEnabled of <
	id   : I.t ;
        post : PostI.t option ;
        pid  : PId.t ;
      >
    | `TrackDisabled of <
	id   : I.t ;
	post : PostI.t option ;
	pid  : PId.t ; 
      > 
    | `MarkedAsRead of <
	id    : I.t ;
        posts : PostI.t list ;
        pid   : PId.t ;    
      >
    | `TrackerGarbageCollected of < 
	id  : I.t ; 
        pid : PId.t ;
      >
    ]
