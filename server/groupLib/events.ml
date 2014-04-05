(* © 2014 RunOrg *)

open Std

include type module 
    [ `Created of < 
        id : GId.t ; 
        cid : CId.t option ; 
	label : String.Label.t option 
      > 
    | `Deleted of < 
	id : GId.t ;
	cid : CId.t option ;
      >
    | `Added   of < 
	cid : CId.t option ;
	contacts : CId.t list ; 
        groups : GId.t list ;
      >
    | `Removed of < 
	cid : CId.t option ;
	contacts : CId.t list ; 
        groups : GId.t list ;
      >
    ]
