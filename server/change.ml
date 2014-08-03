(* © 2014 RunOrg *)

open Std

type 'a t = [ `Keep | `Set of 'a ]

let apply = function 
  | `Keep  -> identity 
  | `Set x -> (fun _ -> x)

let of_option = function 
  | None -> `Keep
  | Some x -> `Set x

let of_field name data = function 
  | Some x -> `Set (Some x)
  | None -> match data with 
    | Some (`JSON (Json.Object o)) when List.exists (fun (key,_) -> key = name) o -> `Set None
    | _ -> `Keep
