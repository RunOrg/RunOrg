(* © 2014 RunOrg *)

open Std

(* Reading generic information 
   =========================== *)

type info = <
   id : I.t ; 
   count : int ;
   last : Time.t ;
   contacts : CId.t list ;
   groups : Group.I.t list ;
   subject : String.Label.t option ;
   public : bool ;
>

let get id = 
  let! info = Cqrs.MapView.get View.info id in 
  match info with None -> return None | Some info -> return (Some (object
    method id = id 
    method count = info # count
    method last = info # last 
    method contacts = info # contacts
    method groups = info # groups
    method subject = info # subject
    method public = info # public
  end))

(* Reading multiple chatrooms 
   ========================== *)

let all_as ?(limit=100) ?(offset=0) cid = 

  let! gids = Group.of_contact cid in 
  let  accessors = View.Accessor.( Public :: Contact cid :: List.map (fun gid -> Group gid) gids ) in

  let rec fetch limit offset = 

    let! ids = Cqrs.ManyToManyView.join ~limit ~offset View.access accessors in 
    let  idN = List.length ids in    
    
    let! infos = List.M.filter_map get ids in 
    let  infoN = List.length infos in 
    
    if idN = infoN || idN < limit then return infos else 
      let! more = fetch (limit - infoN) (offset + limit) in
      return (infos @ more)

  in
  
  fetch limit offset

(* Reading items 
   ============= *)

type item = <
  id : MI.t ;
  author : CId.t ;
  time : Time.t ;
  body : String.Rich.t ;
>

let list ?(limit=1000) ?(offset=0) id = 
  let! list = Cqrs.FeedMapView.list View.items ~limit ~offset id in 
  return (List.map (fun (id,t,value) -> (object
    method id = id
    method time = t
    method author = value # author
    method body = value # body
  end)) list)
