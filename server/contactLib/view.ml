(* © 2014 RunOrg *)

open Std

let projection = Cqrs.Projection.make "contact" (fun () -> new O.ctx) 

(* Contact identifier by e-mail. *)
module S = type module string

let byEmail =
 
  let byEmailV, byEmail = Cqrs.MapView.make projection "all" 0
    (module S : Fmt.FMT with type t = string)
    (module I : Fmt.FMT with type t = I.t) in

  let () = Store.track byEmailV begin function 

    | `Created ev -> 
      
      Cqrs.MapView.update byEmail (ev # email) 
	(function 
	| None   -> `Put (ev # id)
	| Some _ -> `Keep)

    | `FirstnameSet _ 
    | `LastnameSet _
    | `FullnameSet _ 
    | `GenderSet _ -> return () 
	
  end in 

  byEmail 
      
