(* © 2014 RunOrg *)

open Std

include type module
    [ `Created of < 
	id : I.t ; 
        label : String.Label.t option ; 
	owner : Owner.t ; 
	fields : Field.t list ;
	custom : Json.t ;
      >
    | `Filled of <
        id : I.t ;
	fid : FilledI.t ;
	data : FillData.t ;
      >
    ]
