(* © 2014 RunOrg *)

open Std

include type module 
    [ `Created of < id : PId.t ; email : String.Label.t >

    | `InfoCreated of < 
	id : PId.t ; 
        name : String.Label.t option ; 
	familyName : String.Label.t option ; 
	givenName : String.Label.t option ; 
	gender : [`F|`M] option 
      >

    | `InfoUpdated of <
	id         : PId.t ;
	name       : [ `Keep | `Set of String.Label.t option ] ;
	familyName : [ `Keep | `Set of String.Label.t option ] ;
	givenName  : [ `Keep | `Set of String.Label.t option ] ;
	gender     : [ `Keep | `Set of [`F|`M] option ] ;
	email      : [ `Keep | `Set of String.Label.t ] ;	
      >

    ]
