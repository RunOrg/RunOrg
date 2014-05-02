(* © 2014 RunOrg *)

open Std

let projection = Cqrs.Projection.make "person" O.config

(* Person identifier by e-mail. *)

let byEmail =
 
  let byEmailV, byEmail = Cqrs.MapView.make projection "all" 0
    (module String.Label : Fmt.FMT with type t = String.Label.t)
    (module PId : Fmt.FMT with type t = PId.t) in

  let () = Store.track byEmailV begin function 

    | `Created ev -> 
      
      Cqrs.MapView.update byEmail (ev # email) 
	(function 
	| None   -> `Put (ev # id)
	| Some _ -> `Keep)

    | `InfoUpdated _ -> return () 
	
  end in 

  byEmail 
      
(* Short person details by id *)

module Short = type module < 
  email  : String.Label.t ;
  label  : String.Label.t ; 
  force  : bool ; 
  gender : [`F|`M] option 
>

(* Computes the new full name. 
   - If provided explicitly, keep and mark as forced.
   - If was forced earlier, keep older and mark as forced.
   - Combine given name and family name, do not mark as forced. *)
let new_name force oldName newName givenName familyName = 
  match newName with Some _ -> true, newName | None -> 
    if force && oldName <> None then true, oldName else
      false, match givenName, familyName with 
        | None, None -> None
	| Some name, None 
	| None, Some name -> Some name
	| Some gn, Some fn -> let gns = String.Label.to_string gn in
			      let fns = String.Label.to_string fn in 
			      match String.Label.of_string (gns ^ " " ^ fns) with 
			      | None   -> Some gn
			      | Some l -> Some l

let no_label = 
  match String.Label.of_string "???" with 
  | Some label -> label
  | None -> assert false
  
let new_label email nameopt = 
  match nameopt with Some name -> name | None -> 
    try let first, _ = String.split (String.Label.to_string email) "@" in 
	match String.Label.of_string (first ^ "@…") with 
	| Some label -> label
	| None -> no_label
    with Not_found -> no_label (* <-- No '@' in email: allow leak. *)
			      
let short = 
  
  let shortV, short = Cqrs.MapView.make projection "short" 0
    (module PId : Fmt.FMT with type t = PId.t)
    (module Short : Fmt.FMT with type t = Short.t)  in

  let () = Store.track shortV begin function 

    | `Created ev -> 

      let label = new_label (ev # email) None in 
      Cqrs.MapView.update short (ev # id) 
	(function 
	| None -> `Put (Short.make ~email:(ev # email) ~label ~force:false ~gender:None)
	| Some o -> `Keep)

    | `InfoUpdated ev -> 

      Cqrs.MapView.update short (ev # id) 
	(function None -> `Keep | Some old -> 
	  let force, name = new_name (old # force) 
	    (Some (old # label)) (ev # name) (ev # givenName) (ev # familyName) in
	  let label  = if force || not (old # force) then new_label (old # email) name else old # label in
	  let gender = if ev # gender = None then old # gender else ev # gender in
	  `Put (Short.make ~email:(old # email) ~label ~force ~gender))

  end in    

  short

(* Search index (by short.name) *)

let search = 

  let searchV, search = Cqrs.SearchView.make projection "search" 2
    (module PId : Fmt.FMT with type t = PId.t) in

  let update id =
    let! info  = Cqrs.MapView.get short id in 
    let  words = match info with 
      | None -> [] 
      | Some info -> String.Word.index (String.Label.to_string (info # label)) in
    Cqrs.SearchView.set search id words 
  in

  let () = Store.track searchV begin function 

    | `Created ev -> update (ev # id) 
    | `InfoUpdated ev -> update (ev # id) 

  end in    

  search

(* Full contact information 
   ======================== *)

module Full = type module < 
  email      : String.Label.t ;
  label      : String.Label.t ; 
  name       : String.Label.t option ; 
  givenName  : String.Label.t option ;
  familyName : String.Label.t option ; 
  force      : bool ; (* True if 'name' was provided directly. *)
  gender     : [`F|`M] option ;
>

let full = 
  
  let fullV, full = Cqrs.MapView.make projection "full" 0
    (module PId : Fmt.FMT with type t = PId.t)
    (module Full : Fmt.FMT with type t = Full.t)  in

  let () = Store.track fullV begin function 

    | `Created ev -> 

      let label = new_label (ev # email) None in 
      Cqrs.MapView.update full (ev # id) 
	(function 
	| None -> `Put (Full.make ~email:(ev # email) ~label ~gender:None
			  ~name:None ~familyName:None ~givenName:None ~force:false )
	| Some o -> `Keep)

    | `InfoUpdated ev -> 

      Cqrs.MapView.update full (ev # id) 
	(function None -> `Keep | Some old -> 
	  let force, name = new_name (old # force) (old # name) 
	    (ev # name) (ev # givenName) (ev # familyName) in
	  let label = new_label (old # email) name in
	  let gender = if ev # gender = None then old # gender else ev # gender in
	  `Put (Full.make ~email:(old # email) ~label ~name ~force ~gender
		  ~givenName:(ev # givenName) ~familyName:(ev # familyName)))

  end in    

  full

