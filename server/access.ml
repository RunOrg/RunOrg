(* © 2014 RunOrg *)

open Std

module type ACCESS_LEVEL = sig
  include Fmt.FMT
  val all : (t * (t list)) list 
end

module Make = functor (Access:ACCESS_LEVEL) -> struct

  open Audience

  (* Audience serialization 
     ====================== *)

  module Audience = Fmt.Make(struct

    type t = ( Access.t, Audience.t ) Map.t

    let json_of_t t = 
      Json.Object (List.map (fun (k,v) ->
	let k = Access.to_json k in 
	let v = Audience.to_json v in 
	let k = match k with Json.String s -> s | json -> failwith "Access should serialize to string" in 
	(k, v) 
      ) (Map.to_list t))

    let t_of_json = function 
      | Json.Object o -> begin
	Map.of_list (List.map (fun (k,v) -> 
	  let v = try Audience.of_json v with Json.Error (path,error) -> 
	    raise (Json.Error (k :: path, error)) in
	  let k = try Access.of_json (Json.String k) with Json.Error (path,error) -> 
	    raise (Json.Error ([k], "Unrecognized access level.")) in
	  (k, v) 	  
	) o)
      end
      | json -> Json.parse_error "Expected object." json 

    module Packed = type module (Access.t * Audience.t) list 

    let pack t p = Packed.pack (Map.to_list t) p
    let unpack u = Map.of_list (Packed.unpack u)

  end)

  (* Access set serialization 
     ======================== *)

  module AccessSet = Fmt.Map(struct

    module Inner = type module (Access.t list)

    type t = Access.t Set.t

    let from_inner l = Set.of_list l
    let to_inner t = Set.to_list t

  end)

  (* Computing access level sets 
     =========================== *)

  let sorted_by_size = Access.all
    |> List.map (fun (n,l) -> n, List.length l)
    |> List.sort (fun (_,a) (_,b) -> compare b a) 
    |> List.map fst

  let dependencies = Access.all
    |> List.map (fun (n,l) -> n, Set.of_list l)
    |> Map.of_list 

  let compute id audiences = 

    let is_member = is_member id in 

    let audience access = 
      try union (Map.find access audiences) admin with Not_found -> admin in 

    let rec fill set = function [] -> return set | access :: rest -> 
      let! is_member = if Set.mem access set then return true else is_member (audience access) in
      let set = if is_member then Set.add access (Set.union set (Map.find access dependencies)) else set in
      fill set rest
    in

    fill Set.empty sorted_by_size

end
