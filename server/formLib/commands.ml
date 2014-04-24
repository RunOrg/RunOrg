(* © 2014 RunOrg *)

open Std

(* Creating a form 
   =============== *)

(* Who is allowed to create new forms ? *)
let create_audience = Audience.admin 

let create pid ?label ?id ~owner ~audience ~custom fields =   

  (* If a custom id is used, make sure it is not already in use. *)
  let! newId = match id with 
    | None -> return (Ok (I.gen ())) 
    | Some id -> 
      let  newId = I.of_id (CustomId.to_id id) in
      let! exists = Cqrs.MapView.get View.info newId in 
      return (if exists = None then Ok newId else Bad id) 
  in

  match newId with Bad id -> return (`AlreadyExists id) | Ok id -> 

    let! allowed = Audience.is_member pid create_audience in 

    if not allowed then 
      let! ctx = Run.context in 
      return (`NeedAccess (ctx # db))
    else
      
      let! clock = Store.append [ Events.created ~id ~pid ~label ~owner ~audience ~fields ~custom ] in 
      return (`OK (id, clock)) 
      
(* Updating a form 
   =============== *)

let update ?label ?owner ?audience ?custom ?fields pid id = 
  
  let! form = Cqrs.MapView.get View.info id in 

  match form with None -> return (`NoSuchForm id) | Some form -> 

    let! access = FormAccess.compute pid (form # audience) in
    if not (Set.mem `Fill access) then return (`NoSuchForm id) else
      if not (Set.mem `Admin access) then return (`NeedAdmin id) else

	if label = None && owner = None && audience = None && custom = None && fields = None then
	  return (`OK Cqrs.Clock.empty)
	else 
	  
	  if fields <> None && not (form # empty) then return (`FormFilled id) else
	    
	    let! clock = Store.append [ Events.updated ~id ~pid ~label ~owner ~audience ~fields ~custom ] in
	    return (`OK clock) 

(* Filling the form
   ================ *)

let check_fid pid form id fid = 
  let! access = FormAccess.compute pid (form # audience) in 
  if not (Set.mem `Fill access) then return (Some (`NoSuchForm id)) else    
    match form # owner, fid with 
    | `Person, `Person pid' -> 
      if Set.mem `Admin access || Set.mem `Fill access && pid = Some pid' then      
	let! info = Person.get pid' in 
	return (if info = None then Some (`NoSuchOwner (id,fid)) else None)
      else
	return (Some (`NeedAdmin (id,fid))) 

let is_empty_data = function 
  | Json.Null 
  | Json.String ""
  | Json.Array []
  | Json.Object [] -> true
  | _ -> false

let check_fill form id data = 

  match 
    let field_missing k = not (List.exists (fun f -> f # id = k) (form # fields)) in
    Map.foldi 
      (fun k v acc -> if acc = None && field_missing k then Some k else acc)
      data None
  with Some flid -> return (Some (`NoSuchField (id, flid))) | None -> 

    match 
      List.fold_left 
	(fun acc field -> 
	  let get () = try Map.find (field # id) data with Not_found -> Json.Null in
	  if acc = None && field # required && is_empty_data (get ()) then Some (field # id) else acc)
	None (form # fields) 
    with Some flid -> return (Some (`MissingRequiredField (id, flid))) | None -> 
      
      let! invalid = List.M.find 
	(fun field -> 
	  let! correct = Field.check (field # kind) 
	    (try Map.find (field # id) data with Not_found -> Json.Null) in
	  return (if correct then None else Some field)) 
	(form # fields) in

      match invalid with None -> return None | Some field -> 
	return (Some (`InvalidFieldFormat (id, field # id, field # kind)))

let fill pid id fid data = 

  (* Does the form exist ? *)
  let! form  = Cqrs.MapView.get View.info id in
  match form with None -> return (`NoSuchForm id) | Some form -> 

    let! fid_error = check_fid pid form id fid in
    match fid_error with Some e -> return e | None -> 
      let! fill_error = check_fill form id data in
      match fill_error with Some e -> return e | None -> 

	(* Save the data. *)
	let! clock = Store.append [ Events.filled ~id ~pid ~fid ~data ] in
	return (`OK clock) 
