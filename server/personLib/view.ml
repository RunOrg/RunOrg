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

    | `InfoCreated _  -> return () 
    | `InfoUpdated ev ->
      
      (* TODO: find a way to erase the old binding *)
      (match ev # email with `Keep -> return () | `Set email -> 
	Cqrs.MapView.update byEmail email (fun _ -> `Put (ev # id)))
	
  end in 

  byEmail 
      

(* Computes the new full name. *)
let new_name newName givenName familyName = 
  match newName with Some _ -> newName | None -> 
    match givenName, familyName with 
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
			      
(* Full contact information 
   ======================== *)

module Full = type module < 
  email      : String.Label.t ;
  label      : String.Label.t ; 
  name       : String.Label.t option ; 
  forcedName : String.Label.t option ; 
  givenName  : String.Label.t option ;
  familyName : String.Label.t option ; 
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
			  ~forcedName:None ~name:None ~familyName:None ~givenName:None)
	| Some o -> `Keep)

    | `InfoCreated ev -> 

      Cqrs.MapView.update full (ev # id) 
	(function None -> `Keep | Some old -> 
	  let name = new_name (ev # name) (ev # givenName) (ev # familyName) in
	  let label = new_label (old # email) name in
	  `Put (Full.make ~email:(old # email) ~label ~name 
		  ~forcedName:(ev # name) 
		  ~gender:(ev # gender) 
		  ~givenName:(ev # givenName) 
		  ~familyName:(ev # familyName)))

    | `InfoUpdated ev -> 

      Cqrs.MapView.update full (ev # id) 
	(function None -> `Keep | Some old -> 
	  let givenName = Change.apply (ev # givenName) (old # givenName) in
	  let familyName = Change.apply (ev # familyName) (old # familyName) in
	  let email = Change.apply (ev # email) (old # email) in
	  let gender = Change.apply (ev # gender) (old # gender) in
	  let forcedName = Change.apply (ev # name) (old # forcedName) in
	  let name = new_name forcedName givenName familyName in
	  let label = new_label email name in
	  `Put (Full.make ~email ~label ~name ~forcedName ~gender ~givenName ~familyName))


  end in    

  full

(* Short person details by id 
   ========================== *)

module Short = type module < 
  email  : String.Label.t ;
  label  : String.Label.t ; 
  gender : [`F|`M] option 
>

let short = 
  
  let shortV, short = Cqrs.MapView.make projection "short" 1
    (module PId : Fmt.FMT with type t = PId.t)
    (module Short : Fmt.FMT with type t = Short.t)  in

  let update id = 
    let! current = Cqrs.MapView.get full id in
    match current with None -> return () | Some person ->
      let data = Short.make ~email:(person # email) ~label:(person # label) ~gender:(person # gender) in
      Cqrs.MapView.update short id (fun _ -> `Put data)
  in

  let () = Store.track shortV begin function 

    | `Created     ev -> update (ev # id)
    | `InfoCreated ev -> update (ev # id) 
    | `InfoUpdated ev -> update (ev # id)
      
  end in    

  short

(* Search index (by short.name) 
   ============================ *)

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
    | `InfoCreated ev -> update (ev # id)

  end in    

  search
