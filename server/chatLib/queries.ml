(* © 2014 RunOrg *)

open Std

type info = <
  id : I.t ; 
  count : int ;
  contacts : CId.t list ;
  groups : Group.I.t list ;
>

let get id = 
  let! info = Cqrs.MapView.get View.info id in 
  match info with None -> return None | Some info -> return (Some (object
    method id = id 
    method count = info # count
    method contacts = info # contacts
    method groups = info # groups
  end))

