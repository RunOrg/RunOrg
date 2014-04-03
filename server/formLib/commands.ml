(* © 2014 RunOrg *)

open Std

(* Creating a form 
   =============== *)

let create ?label ?id owner audience custom fields =   

  (* If a custom id is used, make sure it is not already in use. *)
  let! id = match id with 
    | None -> return (Some (I.gen ())) 
    | Some id -> 
      let  id = I.of_id (CustomId.to_id id) in
      let! exists = Cqrs.MapView.get View.info id in 
      return (if exists = None then Some id else None) 
  in

  match id with None -> return (None, Cqrs.Clock.empty) | Some id -> 
    let! clock = Store.append [ Events.created ~id ~label ~owner ~audience ~fields ~custom ] in 
    return (Some id, clock) 

(* Filling the form
   ================ *)

let check_fid form id fid = 
  match form # owner, fid with 
    | `Contact, `Contact cid -> 
      let! info = Contact.get cid in 
      return (if info = None then Some (`NoSuchOwner (id,fid)) else None)

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

let fill id fid data = 

  (* Check that everything is fine *)
  let! form  = Cqrs.MapView.get View.info id in
  match form with None -> return (Bad (`NoSuchForm id)) | Some form -> 
    let! fid_error = check_fid form id fid in
    match fid_error with Some e -> return (Bad e) | None -> 
      let! fill_error = check_fill form id data in
      match fill_error with Some e -> return (Bad e) | None -> 

	(* Save the data. *)
	let! clock = Store.append [ Events.filled ~id ~fid ~data ] in
	return (Ok clock) 
