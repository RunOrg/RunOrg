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

(* Queries 
   ======= *)

let count _ = 
  return 0 

let all ~limit ~offset _ = 
  return []
