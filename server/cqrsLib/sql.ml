(* © 2013 RunOrg *)

open Std

type param = Common.param
type raw_result = Common.result

let query q p = Common.query q p 

let command q p = let! _ = query q p in Run.return () 

(* Registering for first connection. 
   ================================= *)

let run_on_first_connection what =
  let current = !Common.on_first_connection in 
  Common.on_first_connection := (let! () = current in what)

let query_on_first_connection query params =
  run_on_first_connection (command query params)

(* Transactions 
   ============ *)

let mutex = new Run.mutex

let safe_command q p = 
  mutex # if_unlocked (command q p)

let transaction action = 
  mutex # lock begin 
    let! () = command "BEGIN TRANSACTION" [] in
    let! result = action in 
    let! () = command "COMMIT" [] in
    Run.return result
  end 
