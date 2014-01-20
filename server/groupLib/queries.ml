(* © 2014 RunOrg *)

open Std

(* Group information 
   ================= *)

type info = View.Info.t

let get gid = 
  Cqrs.MapView.get View.info gid 

(* Members in the group 
   ==================== *)

let list ?limit ?offset gid = 
  let! count = Cqrs.ManyToManyView.count View.contacts gid in 
  let! list  = Cqrs.ManyToManyView.list ?limit ?offset View.contacts gid in
  return (list, count)

