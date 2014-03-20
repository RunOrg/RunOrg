(* © 2014 RunOrg *)

open Std

module I = struct
  include Id.Phantom
end

module Hash = type module 
    [ `SHA1 "SHA-1" 
    ]

(* Events and event stream 
   ======================= *)

module Events = type module 
    [ `Created of < id : I.t ; ip : IpAddress.t ; hash : Hash.t ; key : string >
    ]

module Store = Cqrs.Stream(struct
  include Events
  let name = "key"
end)

(* Views and projections 
   ===================== *)

let projection = Cqrs.Projection.make "key" (fun () -> new O.ctx)

module Value = type module < hash : Hash.t ; key : string > 

let value = 
  
  let valueV, value = Cqrs.MapView.make projection "value" 0
    (module I : Fmt.FMT with type t = I.t)
    (module Value : Fmt.FMT with type t = Value.t) in

  let () = Store.track valueV begin function 

    | `Created ev -> 

      Cqrs.MapView.update value (ev # id)
	(function 
	| None   -> `Put (ev :> Value.t)
	| Some _ -> `Keep)

  end in
  
  value

(* Commands 
   ======== *)

let create ip hash key = 
  let  id = I.gen () in
  let! clock = Store.append [ Events.created ~id ~hash ~key ~ip ] in
  return (id, clock)
 
(* Queries 
   ======= *)
    
let hmac id bytes = 
  let! info = Cqrs.MapView.get value id in
  match info with None -> return None | Some info -> 
    return (Some begin match info # hash with 

    | `SHA1 -> Sha1.hmac (info # key) bytes

    end)

