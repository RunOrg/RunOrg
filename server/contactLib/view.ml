(* © 2014 RunOrg *)

open Std

let projection = Cqrs.Projection.make "contact" O.config

(* Contact identifier by e-mail. *)

let byEmail =
 
  let byEmailV, byEmail = Cqrs.MapView.make projection "all" 0
    (module String.Label : Fmt.FMT with type t = String.Label.t)
    (module CId : Fmt.FMT with type t = CId.t) in

  let () = Store.track byEmailV begin function 

    | `Created ev -> 
      
      Cqrs.MapView.update byEmail (ev # email) 
	(function 
	| None   -> `Put (ev # id)
	| Some _ -> `Keep)

    | `InfoUpdated _ -> return () 
	
  end in 

  byEmail 
      
(* Short contact details by id *)

module Short = type module < 
  email : String.Label.t ;
  name : String.Label.t ; 
  force : bool ; 
  gender : [`F|`M] option 
>

let short = 
  
  let shortV, short = Cqrs.MapView.make projection "short" 0
    (module CId : Fmt.FMT with type t = CId.t)
    (module Short : Fmt.FMT with type t = Short.t)  in

  let () = Store.track shortV begin function 

    | `Created ev -> 

      Cqrs.MapView.update short (ev # id) 
	(function 
	| None -> `Put (Short.make ~email:(ev # email) ~name:(ev # email) ~force:false ~gender:None)
	| Some o -> `Keep)

    | `InfoUpdated ev -> 

      let force = ev # fullname <> None in 
      let name  = 
	match ev # fullname with Some name -> Some name | None -> 
	  match ev # firstname, ev # lastname with 
  	    | None, None -> None
	    | Some name, None 
	    | None, Some name -> Some name
	    | Some fn, Some ln -> let fns = String.Label.to_string fn in
				  let lns = String.Label.to_string ln in 
				  match String.Label.of_string (fns ^ " " ^ lns) with 
				  | None -> Some fn
				  | Some l -> Some l
      in

      Cqrs.MapView.update short (ev # id) 
	(function None -> `Keep | Some old -> 
	  let name = if force || not (old # force) then Option.default (old # email) name else old # name in
	  let gender = if ev # gender = None then old # gender else ev # gender in
	  `Put (Short.make ~email:(old # email) ~name ~force ~gender))

  end in    

  short

(* Search index (by short.name) *)

let search = 

  let searchV, search = Cqrs.SearchView.make projection "search" 2
    (module CId : Fmt.FMT with type t = CId.t) in

  let update id =
    let! info  = Cqrs.MapView.get short id in 
    let  words = match info with 
      | None -> [] 
      | Some info -> String.Word.index (String.Label.to_string (info # name)) in
    Cqrs.SearchView.set search id words 
  in

  let () = Store.track searchV begin function 

    | `Created ev -> update (ev # id) 
    | `InfoUpdated ev -> update (ev # id) 

  end in    

  search
