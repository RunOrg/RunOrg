(* © 2014 RunOrg *)

open Std

(* Retrieving forms 
   ================ *)

type info = <
  id       : I.t ;
  owner    : Owner.t ;
  label    : String.Label.t option ; 
  fields   : Field.t list ;
  custom   : Json.t ;
  audience : FormAccess.Audience.t ;
  empty    : bool ; 
> 

let make_info id info = object
  method id       = id
  method owner    = info # owner
  method label    = info # label
  method fields   = info # fields
  method custom   = info # custom
  method empty    = info # empty
  method audience = info # audience
end

let get id = 
  let! info = Cqrs.MapView.get View.info id in
  match info with None -> return None | Some info ->
    return (Some (make_info id info))

let list cid ~limit ~offset = 
  let! list = FormAccess.Map.list ~limit ~offset View.byAccess cid `Fill in
  List.M.filter_map get list
  
(* Retrieving filled forms
   ======================= *)

type filled = <
  updated : Time.t ;
  owner   : FilledI.t ;
  data    : (Field.I.t, Json.t) Map.t ;
>

let belongs_to fid pid = match fid with
  | `Person pid' -> pid = Some pid'

let get_filled cid id fid = 

  (* Form should exist... *)
  let! form = Cqrs.MapView.get View.info id in
  match form with None -> return (`NoSuchForm id) | Some form -> 

    (* ...and be visible. *)
    let! access = FormAccess.compute cid (form # audience) in
    if not (Set.mem `Fill access) then return (`NoSuchForm id) else 

      (* The user should have access to the filled instance *)
      if not (Set.mem `Admin access || belongs_to fid cid) then return (`NeedAdmin (id,fid)) else

	(* And the filled instance should exist. *)
	let! info = Cqrs.FeedMapView.get View.fillInfo id fid in
	match info with None -> return (`NotFilled (id,fid)) | Some (_,info) -> 

	  return (`OK (info # data))	
      
let list_filled cid ?limit ?offset id =

  (* Form should exist... *)
  let! form = Cqrs.MapView.get View.info id in  
  match form with None -> return (`NoSuchForm id) | Some form -> 

    (* ...and be visible. *)
    let! access = FormAccess.compute cid (form # audience) in
    if not (Set.mem `Fill access) then return (`NoSuchForm id) else 
      if not (Set.mem `Admin access) then return (`NeedAdmin id) else

	let! list = Cqrs.FeedMapView.list View.fillInfo ?limit ?offset id in
	let! stats = Cqrs.FeedMapView.stats View.fillInfo id in
	
	let  count = stats # count in 
	let  list  = List.map (fun (fid,t,info) -> (object
	  method updated = t
	  method data = info # data
	  method owner = fid
	end)) list in 

	return (`OK (object
	  method count = count
	  method list  = list
	end))

(* Statistics 
   ========== *)

let stats cid id = 

  (* Form should exist... *)
  let! form = Cqrs.MapView.get View.info id in  
  match form with None -> return (`NoSuchForm id) | Some form -> 

    (* ...and be visible. *)
    let! access = FormAccess.compute cid (form # audience) in
    if not (Set.mem `Fill access) then return (`NoSuchForm id) else 
      if not (Set.mem `Admin access) then return (`NeedAdmin id) else
	
	let! summary = Cqrs.HardStuffCache.get Stats.compute id (form # clock) in	
	let! stats = Cqrs.FeedMapView.stats View.fillInfo id in

	return (`OK (object
	  method fields = summary
	  method count = stats # count
	  method updated = stats # last
	end)) 
  
