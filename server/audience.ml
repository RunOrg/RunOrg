(* © 2014 RunOrg *)

open Std

(* Serialization and deserialization 
   ================================= *)

module GroupsAndContacts = Fmt.Map(struct

  module Inner = type module <
    ?groups : Group.I.t list = [] ;
    ?contacts : CId.t list = [] ;
  >

  type t = <
    groups : Group.I.t Set.t ;
    contacts : CId.t Set.t ;
  >

  let from_inner i = object
    val groups = Set.of_list (i # groups)
    method groups = groups
    val contacts = Set.of_list (i # contacts)
    method contacts = contacts
  end

  let to_inner t = object
    val groups = Set.to_list (t # groups)
    method groups = groups
    val contacts = Set.to_list (t # contacts)
    method contacts = contacts
  end

end)

let max_item_count = 20

include Fmt.Make(struct

  include type module [ `Anyone | `List of GroupsAndContacts.t ]

  let json_of_t = function 
    | `Anyone -> Json.String "anyone"
    | `List l -> GroupsAndContacts.to_json l 

  let t_of_json = function
    | Json.String "anyone" -> `Anyone
    | (Json.Object _ as obj) -> let l = GroupsAndContacts.of_json obj in
				let lc = Set.cardinal (l # contacts) in
				let lg = Set.cardinal (l # groups) in
				if lc > max_item_count then
				  Json.parse_error 
				    (!! "Audience has %d contacts, maximum is %d" lc max_item_count)
				    obj
				else if lg > max_item_count then
				  Json.parse_error 
				    (!! "Audience has %d elements, maximum is %d" lg max_item_count) 
				    obj
				else
				  `List l 
    | json -> Json.parse_error "Expected audience. " json

end)

let empty = `List (object 
  method groups = Set.empty 
  method contacts = Set.empty
end)

let admins = `List (object 
  method groups = Set.singleton Group.I.admin
  method contacts = Set.empty
end)

(* Testing membership 
   ================== *)

let is_member cid = function 
  | `Anyone -> return true
  | `List l -> 
    if Set.mem cid (l # contacts) then return true else
      let! groups = Group.of_contact cid in 
      return (List.exists (fun gid -> Set.mem gid (l # groups)) groups)

let gac_union a b = object
  val groups = Set.union (a # groups) (b # groups)
  method groups = groups
  val contacts = Set.union (a # contacts) (b # contacts)
  method contacts = contacts
end

let union a b = match a, b with 
  | `Anyone, _ | _, `Anyone -> `Anyone 
  | `List a, `List b -> `List (gac_union a b)

let is_allowed cid audiences = 
  is_member cid (List.fold_left union admins audiences) 
