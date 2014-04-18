(* © 2014 RunOrg *)

open Std

include type module
    [ `Created of < 
	id : I.t ; 
        cid : CId.t option ; 
	from : CId.t ; 
        subject : Unturing.t ;
	audience : MailAccess.Audience.t ; 
	text : Unturing.t option ;
	html : Unturing.t option ;
	custom : Json.t ;
	urls : String.Url.t list ;
	self : String.Url.t option ; 
      >
    ]
