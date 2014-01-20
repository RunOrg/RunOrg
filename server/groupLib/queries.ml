(* © 2014 RunOrg *)

open Std

(* Members in the group 
   ==================== *)

let list ?limit ?offset gid = 
  Cqrs.ManyToManyView.list ?limit ?offset View.contacts gid 
