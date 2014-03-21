(* © 2014 RunOrg *)

open Std

(* Identifiers 
   =========== *)

module I = struct
  include Id.Phantom
  let of_custom c = of_id (CustomId.to_id c)
end

(* Choices
   ======= *)

module Choice = Fmt.Make(struct

  type t = [ `Label of String.Label.t | `Custom of Json.t ]

  let t_of_json = function
    | (Json.String _) as json -> `Label (String.Label.of_json json)
    | json -> `Custom json 

  let json_of_t = function 
    | `Label  labl -> String.Label.to_json labl
    | `Custom json -> json 

  let pack c = 
    Json.pack (json_of_t c)

  let unpack bytes =
    t_of_json (Json.unpack bytes)

end)

(* Kinds of fields 
   =============== *)

module Kind = type module 
  [ `Text           "text"
  | `RichText       "rich"
  | `DateTime       "time"
  | `SingleChoice   "single" of Choice.t list
  | `MultipleChoice "multiple" of Choice.t list 
  | `Json           "json"
  | `Contact        "contact"
  ]

(* Meta-data 
   ========= *)

include type module <
  id       : I.t ;
  kind     : Kind.t ;
  label    : String.Label.t ;
  custom   : Json.t ; 
  required : bool ;
>

