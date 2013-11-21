(* © 2013 RunOrg *)

open Std

type param = Common.param
type raw_result = Common.result

let query q p = Common.query q p 

let command q p = let! _ = query q p in Run.return () 

(* Registering for first connection. 
   ================================= *)

let on_first_connection what =
  let current = !Common.on_first_connection in 
  Common.on_first_connection := (let! () = current in what)

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
