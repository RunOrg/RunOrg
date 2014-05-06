(* © 2013 RunOrg *)

open Std

type param = SqlConnection.param
type raw_result = SqlConnection.result

let query q p = 
  let! ctx = Run.context in
  SqlConnection.execute (ctx # cqrs) q p 

let command q p = 
  let! _ = query q p in 
  return () 

(* Registering for first connection. 
   ================================= *)

let on_first_connection what =
  let current = !Common.on_first_connection in 
  Common.on_first_connection := (let! () = current in what)

(* Transactions 
   ============ *)

(* We only allow one transaction at a time for the entire process. *)
let mutex = new Run.mutex

let safe_query q p = 
  mutex # if_unlocked (query q p)

let transaction action = 
  mutex # lock begin 
    let! ctx = Run.context in     
    let! () = SqlConnection.transaction (ctx # cqrs) in
    let! result = action in 
    let! () = SqlConnection.commit (ctx # cqrs) in
    return result
  end 

(* Pooling 
   ======= *)

let using config mkctx thread = 
  let conn = SqlConnection.connect config in
  let ctx : #Common.ctx = mkctx conn in
  let thread = Run.with_context ctx thread in
  let clean () = SqlConnection.release conn in
  Run.finally clean thread
