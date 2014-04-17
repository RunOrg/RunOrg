(* © 2014 RunOrg *)

open Std

include type module
    [ `Created of < 
	id : I.t ; 
        cid : CId.t option ; 
        subject : [ `Raw of String.Label.t ] ;
	audience : MailAccess.Audience.t ; 
	text : [ `None | `Raw of String.Rich.t ] ;
	html : [ `None | `Raw of String.Rich.t ] ;
      >
    ]
