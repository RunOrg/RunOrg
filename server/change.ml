(* © 2014 RunOrg *)

open Std

type 'a t = [ `Keep | `Set of 'a ]

let apply = function 
  | `Keep  -> identity 
  | `Set x -> (fun _ -> x)
