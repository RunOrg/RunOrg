(* © 2014 RunOrg *)

open Std

let create () = 
  let  id = I.gen () in 
  let! clock = Store.append [ Events.created ~id ] in
  return (id, clock) 
