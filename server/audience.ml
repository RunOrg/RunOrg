(* © 2014 RunOrg *)

open Std

(* Serialization and deserialization 
   ================================= *)

module GroupsAndPeople = Fmt.Map(struct

  module Inner = type module <
    ?groups : GId.t list = [] ;
    ?people : PId.t list = [] ;
  >

  type t = <
    groups : GId.t Set.t ;
    people : PId.t Set.t ;
  >

  let from_inner i = object
    val groups = Set.of_list (i # groups)
    method groups = groups
    val people = Set.of_list (i # people)
    method people = people
  end

  let to_inner t = object
    val groups = Set.to_list (t # groups)
    method groups = groups
    val people = Set.to_list (t # people)
    method people = people
  end

end)

let max_item_count = 20

include Fmt.Make(struct

  include type module [ `Anyone | `List of GroupsAndPeople.t ]

  let json_of_t = function 
    | `Anyone -> Json.String "anyone"
    | `List l -> GroupsAndPeople.to_json l 

  let t_of_json = function
    | Json.String "anyone" -> `Anyone
    | (Json.Object _ as obj) -> let l = GroupsAndPeople.of_json obj in
				let lc = Set.cardinal (l # people) in
				let lg = Set.cardinal (l # groups) in
				if lc > max_item_count then
				  Json.parse_error 
				    (!! "Audience has %d people, maximum is %d" lc max_item_count)
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
  method people = Set.empty
end)

let admin = `List (object 
  method groups = Set.singleton GId.admin
  method people = Set.empty
end)

(* Testing membership 
   ================== *)

let ref_of_person : (PId.t -> (Cqrs.ctx, GId.t Set.t) Run.t) ref = 
  ref (fun _ -> assert false)

let of_person cid =
  Run.edit_context (fun ctx -> (ctx :> Cqrs.ctx)) ((!ref_of_person) cid)

let register_groups_of_person f = 
  ref_of_person := f

let is_member = function 
  | None -> (fun x -> return (x = `Anyone)) 
  | Some cid -> 
    let get_groups = Run.memo (of_person cid) in 
    function 
    | `Anyone -> return true
    | `List l -> 
      if Set.mem cid (l # people) then return true else
	let! groups = get_groups in 
	return (not (Set.is_empty (Set.intersect (l # groups) groups)))

let gac_union a b = object
  val groups = Set.union (a # groups) (b # groups)
  method groups = groups
  val people = Set.union (a # people) (b # people)
  method people = people
end

let union a b = match a, b with 
  | `Anyone, _ | _, `Anyone -> `Anyone 
  | `List a, `List b -> `List (gac_union a b)

