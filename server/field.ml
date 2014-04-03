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

(* Data validation 
   =============== *)

let check_text = function
  | Json.String _ 
  | Json.Null -> return true
  | _ -> return false

let check_richText json = 
  return (json = Json.Null || None <> Std.String.Rich.of_json_safe json)

let check_dateTime json = 
  return (json = Json.Null || None <> Time.of_json_safe json)

let check_multipleChoice l = function 
  | Json.Array a -> let n = List.length l in 
		    return (List.for_all (function Json.Int i -> i >= 0 && i < n | _ -> false) a)
  | Json.Null -> return true
  | _ -> return false

let check_singleChoice l = function
  | Json.Int i -> let n = List.length l in
		  return (i >= 0 && i < n)
  | Json.Null -> return true
  | _ -> return false

let check_contact json = 
  if json = Json.Null then return true else 
    match CId.of_json_safe json with None -> return false | Some id ->
      let! contact = Contact.get cid in 
      return (contact <> None) 

let check = function 
  | `Text     -> check_text
  | `RichText -> check_richText    
  | `DateTime -> check_dateTime
  | `SingleChoice   l -> check_singleChoice l 
  | `MultipleChoice l -> check_multipleChoice l 
  | `Json     -> (fun _ -> return true)
  | `Contact  -> check_contact
