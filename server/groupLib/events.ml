(* © 2014 RunOrg *)

open Std

include type module 
    [ `Created of < 
        id       : GId.t ; 
        pid      : PId.t option ; 
	label    : String.Label.t option ;
	audience : GroupAccess.Audience.t ; 
      > 
    | `Deleted of < 
	id  : GId.t ;
	pid : PId.t option ;
      >
    | `Added   of < 
	pid    : PId.t option ;
	people : PId.t list ; 
        groups : GId.t list ;
      >
    | `Removed of < 
	pid    : PId.t option ;
	people : PId.t list ; 
        groups : GId.t list ;
      >
    | `Updated of <
        id       : GId.t ; 
        pid      : PId.t option ; 
	label    : [ `Keep | `Set of String.Label.t option ] ;
	audience : [ `Keep | `Set of GroupAccess.Audience.t ] ; 
      >	
    ]
