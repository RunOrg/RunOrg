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

module KindName = type module 
    [ `Text           "text"
    | `RichText       "rich"
    | `DateTime       "time"
    | `SingleChoice   "single" 
    | `MultipleChoice "multiple" 
    | `Json           "json"
    | `Contact        "contact"
    ]

module Kind = Fmt.Map(struct

  (* For forward compatibility reasons, keeping an empty object tied to each node. Keep in 
     mind that such objects are represented internally as lists, so keeping an empty list 
     will be forward-compatible. *)

  module Inner = type module 
      [ `Text           of unit list 
      | `RichText       of unit list 
      | `DateTime       of unit list 
      | `SingleChoice   of < 
	  choices : Choice.t list ;
	>
      | `MultipleChoice of < 
	  choices : Choice.t list ;
	>
      | `Json           of unit list 
      | `Contact        of unit list 
      ]

  type t = 
      [ `Text           
      | `RichText       
      | `DateTime       
      | `SingleChoice   of Choice.t list 
      | `MultipleChoice of Choice.t list 
      | `Json           
      | `Contact        
      ]

  let from_inner = function 
    | `Text _ -> `Text
    | `RichText _ -> `RichText
    | `DateTime _ -> `DateTime
    | `SingleChoice o -> `SingleChoice (o # choices) 
    | `MultipleChoice o -> `MultipleChoice (o # choices) 
    | `Json _ -> `Json
    | `Contact _ -> `Contact

  let to_inner = function 
    | `Text -> `Text []
    | `RichText -> `RichText []
    | `DateTime -> `DateTime []
    | `SingleChoice choices -> Inner.singleChoice ~choices
    | `MultipleChoice choices -> Inner.multipleChoice ~choices
    | `Json -> `Json []
    | `Contact -> `Contact []

end)

(* Meta-data 
   ========= *)

let max_choices = 20

module InnerFormat = type module <
  id       : I.t ;
  kind     : Kind.t ;
  label    : String.Label.t ;
  custom   : Json.t ;    
  required : bool ;
>

let make = InnerFormat.make

include Fmt.Make(struct

  include InnerFormat
  
  (* The JSON format is subtly different from the internal 
     representation : the properties of the kind are lifted to the 
     object itself. *)

  module JsonFormat = type module <
    id       : I.t ;
    kind     : KindName.t ;
    label    : String.Label.t ;
   ?custom   : Json.t = Json.Null ;
   ?choices  : Choice.t list = [] ;
   ?required : bool = false ;
  >
    
  let t_of_json json = 
    let o = JsonFormat.of_json json in
    (object
      method id = o # id
      method label = o # label 
      method kind = match o # kind with 
      | `Text -> `Text 
      | `RichText -> `RichText
      | `Json -> `Json
      | `DateTime -> `DateTime
      | `Contact -> `Contact
      | `MultipleChoice -> `MultipleChoice (o # choices)
      | `SingleChoice -> `SingleChoice (o # choices)
      method custom = o # custom 
      method required = o # required
     end)

  let json_of_t t =
    JsonFormat.to_json (object
      method id = t # id
      method label = t # label
      method kind = match t # kind with 
      | `Text -> `Text 
      | `RichText -> `RichText
      | `Json -> `Json
      | `DateTime -> `DateTime
      | `Contact -> `Contact
      | `MultipleChoice _ -> `MultipleChoice 
      | `SingleChoice _ -> `SingleChoice 
      method custom = t # custom
      method required = t # required
      method choices = match t # kind with      
      | `Text 
      | `RichText 
      | `Json 
      | `DateTime
      | `Contact -> []
      | `MultipleChoice list
      | `SingleChoice list -> list
    end)

end)

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
    match CId.of_json_safe json with None -> return false | Some cid ->
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
