(* © 2013 RunOrg *)

open Std

(* Event stream 
   ============ *)

module Event = type module 
    [ `DatabaseCreated of string
    ]

module Stream = Cqrs.Stream(struct
  include Event
  let name = "db"
end)

(* Commands 
   ======== *)

let create _ label = 
  let  id = Id.gen () in
  let  event = `DatabaseCreated label in
  let! clock = Run.edit_context (fun ctx -> ctx # with_db id) (Stream.append [event]) in
  return (id, clock) 

(* Projection and views
   ==================== *)

module View = struct

  let projection = Cqrs.Projection.make "db" (fun () -> new O.ctx) 

  (* A view of all databases *)
  module Item = type module < created : Time.t ; label : string >
  let all = 

    let allV, all = Cqrs.MapView.make projection "all" 0 
      (module Id : Fmt.FMT with type t = Id.t)
      (module Item : Fmt.FMT with type t = Item.t) in

    let () = Stream.track allV begin function 

      | `DatabaseCreated label -> 
	let! ctx  = Run.context in 
	let  created = ctx # time and id = ctx # db in 
	Cqrs.MapView.update all id (fun _ -> `Put (Item.make ~created ~label))

    end in 

    all
    
end

(* Queries 
   ======= *)

let count _ = 
  Cqrs.MapView.count View.all 

let all ~limit ~offset _ = 
  let  limit  = clamp 0 100000 limit in 
  let  offset = clamp 0 max_int offset in 
  let! list = Cqrs.MapView.all ~limit ~offset View.all in
  return (List.map (fun (id, db) -> (object 
    method id = id
    method created = db # created
    method label = db # label
  end)) list)
