(* © 2014 RunOrg *)

open Std

include type module 
    [ `Created of < id : I.t ; label : String.Label.t option > 
    | `Deleted of < id : I.t >
    | `Added   of < contacts : CId.t list ; groups : I.t list >
    | `Removed of < contacts : CId.t list ; groups : I.t list >
    ]
