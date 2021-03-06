(* © 2014 RunOrg *)

open Std

include type module
    [ `Created of < 
	id : I.t ; 
        pid : PId.t option ; 
        label : String.Label.t option ; 
	owner : Owner.t ; 
	fields : Field.t list ;
	custom : Json.t ;
	audience : FormAccess.Audience.t ; 
      >
    | `Updated of <
	id : I.t ;
        pid : PId.t option ; 
        label : String.Label.t option option ;    
	owner : Owner.t option ;
	fields : Field.t list option ;
	custom : Json.t option ;
	audience : FormAccess.Audience.t option ;
      >
    | `Filled of <
        id : I.t ;
        pid : PId.t option ; 
	fid : FilledI.t ;
	data : FillData.t ;
      >
    | `Deleted of <
        id : I.t ;
	pid : PId.t option ;
      >
    ]
      
