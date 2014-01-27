(* © 2014 RunOrg *)

open Std

(* Group information 
   ================= *)

type info = <
  id    : I.t ;
  label : String.Label.t option ; 
  count : int ;
>

let get gid = 
  let! info = Cqrs.MapView.get View.info gid in
  match info with None -> return None | Some info -> return (Some (object
    method id = gid
    method label = info # label
    method count = info # count
  end))

(* Members in the group 
   ==================== *)

let list ?limit ?offset gid = 
  let! count = Cqrs.ManyToManyView.count View.contacts gid in 
  let! list  = Cqrs.ManyToManyView.list ?limit ?offset View.contacts gid in
  return (list, count)

