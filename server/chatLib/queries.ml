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

type item = <
  id : MI.t ;
  author : CId.t ;
  time : Time.t ;
  body : string ;
>

let list ?(limit=1000) ?(offset=0) id = 
  let! list = Cqrs.FeedMapView.list View.items ~limit ~offset id in 
  return (List.map (fun (id,t,value) -> (object
    method id = id
    method time = t
    method author = value # author
    method body = value # body
  end)) list)
