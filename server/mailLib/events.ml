(* © 2014 RunOrg *)

open Std

include type module
    [ `Created of < 
	id : I.t ; 
        cid : CId.t option ; 
	from : CId.t ; 
        subject : [ `Raw of String.Label.t ] ;
	audience : MailAccess.Audience.t ; 
	text : [ `None | `Raw of string ] ;
	html : [ `None | `Raw of String.Rich.t ] ;
      >
    ]
