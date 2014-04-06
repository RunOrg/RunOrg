(* © 2014 RunOrg *)

open Std

module type ACCESS_LEVEL = sig
  include Fmt.FMT
  val all : (t * (t list)) list 
end

module type T = sig
  include Fmt.FMT 
  module Audience : Fmt.FMT with type t = ( t, Audience.t ) Map.t
  module Set : Fmt.FMT with type t = t Set.t
  val compute : CId.t option -> Audience.t -> (#Cqrs.ctx, Set.t) Run.t				   
  val set_to_string : Set.t -> string
  type 'id accessor
  module Map : sig
    val make : Cqrs.Projection.t -> string -> int -> ?only:t list -> 
      (module Fmt.FMT with type t = 'id) ->
      Cqrs.Projection.view * 'id accessor
    val update : 'id accessor -> 'id -> Audience.t -> # Cqrs.ctx Run.effect
    val remove : 'id accessor -> 'id -> # Cqrs.ctx Run.effect
    val list : 
      ?limit:int -> 
      ?offset:int -> 
      'id accessor -> 
      CId.t option -> 
      t -> 
      (# Cqrs.ctx, 'id list) Run.t
  end      			
end


module Make = functor (Access:ACCESS_LEVEL) -> struct

  open Audience

  include Access

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

  let set_to_string t = 
    AccessSet.to_json_string t

  (* More optimal management of the access graph 
     =========================================== *)

  let parents = 
    let memoize = ref Map.empty in
    let rec get access = 
      try Map.find access (!memoize) with Not_found -> 
	let parents = List.(map fst (filter (fun (k,v) -> List.mem access v) Access.all)) in
	let set = List.fold_left (fun set a -> Set.union (get a) set) (Set.singleton access) parents in
	memoize := Map.add access set (!memoize) ;
	set
    in
    get

  (* Accessor implementation 
     ======================= *)

  module Who = type module
    | Contact of Access.t * CId.t 
    | Group   of Access.t * GId.t
    | Anon    of Access.t 

  type 'id accessor = <
    map  : (Who.t, 'id) Cqrs.ManyToManyView.t ;
    only : Access.t list ;
  >

  module Map = struct

    (* Creating a new accessor map 
       =========================== *)

    let make proj name version ?only id = 

      let mapV, map = Cqrs.ManyToManyView.make proj name version 
	(module Who : Fmt.FMT with type t = Who.t)
	id in

      let only = match only with Some only -> only | None -> List.map fst Access.all in
      
      mapV, (object
	method map = map
	method only = only 
       end)

    (* Updating the accessor map 
       ========================= *)

    let remove accessor id = 
      Cqrs.ManyToManyView.( delete (flip (accessor # map)) id ) 

    let update accessor id audiences = 
      
      let! () = remove accessor id in
      
      let who_of_audience access = function `Anyone -> [ Who.Anon access ] | `List l -> 
	  List.map (fun cid -> Who.Contact (access,cid)) (Set.to_list (l # contacts)) 
	  @ List.map (fun gid -> Who.Group (access,gid)) (Set.to_list (l # groups))
      in
      
      let audience_of_access access = 
	Set.fold 
	  (fun a aud -> try union aud (Map.find a audiences) with Not_found -> aud) 
	  (parents access) admin
      in

      let who = accessor # only
	|> List.map (fun a -> who_of_audience a (audience_of_access a)) 
	|> List.flatten
      in
      
      Cqrs.ManyToManyView.add (accessor # map) who [id] 
      
    (* Listing elements by accessor 
       ============================ *)

    let list ?limit ?offset accessor cid access = 

      let  of_contact cid = Run.edit_context (fun ctx -> (ctx :> Cqrs.ctx)) (of_contact cid) in

      let! groups = match cid with Some cid -> of_contact cid | None -> return Set.empty in
      let  list   = List.map (fun gid -> Who.Group (access,gid)) (Set.to_list groups) in 
      let  list   = match cid with Some cid -> Who.Contact (access,cid) :: list | None -> list in
      let  list   = Who.Anon access :: list in 

      Cqrs.ManyToManyView.join ?limit ?offset (accessor # map) list 

  end

  module Set = AccessSet

end
