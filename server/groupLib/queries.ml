(* © 2014 RunOrg *)

open Std

(* Group information 
   ================= *)

type info = <
  id    : GId.t ;
  label : String.Label.t option ; 
  count : int ;
>

let format_info gid info = object
  method id = gid
  method label = info # label
  method count = info # count
end 

let get gid = 
  let! info = Cqrs.MapView.get View.info gid in
  match info with None -> return None | Some info -> return (Some (format_info gid info))

let all ~limit ~offset = 
  let! list = Cqrs.MapView.all ~limit ~offset View.info in
  let! count = Cqrs.MapView.count View.info in 
  return (List.map (fun (gid,info) -> format_info gid info) list, count) 

(* Members in the group 
   ==================== *)

let list ?limit ?offset gid = 
  let! count = Cqrs.ManyToManyView.count View.people gid in 
  let! list  = Cqrs.ManyToManyView.list ?limit ?offset View.people gid in
  return (list, count)

(* Groups of a member
   ================== *)

let of_person cid = 
  let  groups = Cqrs.ManyToManyView.flip View.people in 
  let! list = Cqrs.ManyToManyView.list groups cid in
  return (Set.of_list list) 

let () = 
  Audience.register_groups_of_person of_person
