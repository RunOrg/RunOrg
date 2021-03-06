(* © 2014 RunOrg *)

open Std

(* Short profile 
   ============= *)

type short = <
  id     : PId.t ;
  label  : String.Label.t ; 
  pic    : string ; 
  gender : [`F|`M] option ; 
>

let format_short pid short = object
  method id     = pid
  method label  = short # label
  method gender = short # gender
  method pic    = Gravatar.pic_of_email (String.Label.to_string (short # email))
end

let initial_short pid email = object
  method id     = pid
  method label  = email
  method gender = None
  method pic    = Gravatar.pic_of_email (String.Label.to_string email)
end  

(* Unfiltered access
   ================= *)

let get pid = 
  let! found = Cqrs.MapView.get View.short pid in 
  match found with None -> return None | Some short -> return (Some (format_short pid short))

let all_audience = Audience.admin

let all pid ~limit ~offset = 
  let! allowed = Audience.is_member pid all_audience in 
  if not allowed then 
      let! ctx = Run.context in 
      return (`NeedAccess (ctx # db))
  else
    let! list = Cqrs.MapView.all ~limit ~offset View.short in
    let! count = Cqrs.MapView.count View.short in 
    return (`OK (List.map (fun (pid,short) -> format_short pid short) list, count))

(* Filtered access 
   =============== *)

let search pid ?(limit=10) prefix = 

  let! allowed = Audience.is_member pid all_audience in 
  if not allowed then 
      let! ctx = Run.context in 
      return (`NeedAccess (ctx # db))
  else
    let  exact, prefix = String.Word.for_prefix_search prefix in 
    let! ids = 
      if exact = [] then Cqrs.SearchView.find ~limit View.search prefix else
	
	let limit = limit * 10 in
	let! lists = List.M.map identity 
	  (Cqrs.SearchView.find ~limit View.search prefix 
	   :: List.map (Cqrs.SearchView.find_exact ~limit View.search) exact) in
	
	(* [id, n] where n is the number of times id was returned by a search *)
	let ids = List.map (function 
	  | [] -> assert false (* Cannot be returned by List.group *)
	  | (h :: _) as l -> h, List.length l) 
	  (List.group compare (List.flatten lists)) in
      
	let ids = List.sort (fun (_,a) (_,b) -> compare b a) ids in 
	
	return (List.map fst (List.take limit ids))
    in  
    
    let! list = List.M.filter_map get ids in
    return (`OK list) 
  
(* Full profile 
   ============ *)

type full = <
  id         : PId.t ;
  label      : String.Label.t ;
  pic        : string ; 
  gender     : [`F|`M] option ; 
  email      : String.Label.t ; 
  name       : String.Label.t option ; 
  givenName  : String.Label.t option ;
  familyName : String.Label.t option ; 
>

let format_full pid full = object
  method id         = pid
  method label      = full # label
  method gender     = full # gender
  method email      = full # email
  method pic        = Gravatar.pic_of_email (String.Label.to_string (full # email))
  method name       = full # name
  method givenName  = full # givenName
  method familyName = full # familyName
end 

let full_forced pid = 
  let! found = Cqrs.MapView.get View.full pid in 
  match found with 
  | None -> return None
  | Some full -> return (Some (format_full pid full))

let full_audience = Audience.admin

let can_view_full who pid = 
  if who = Some pid then return true else Audience.is_member who full_audience

let full who pid = 
  let! allowed = can_view_full who pid in 
  if not allowed then 
      let! ctx = Run.context in 
      return (`NeedAccess (ctx # db))
  else
    let! found = Cqrs.MapView.get View.full pid in 
    match found with 
    | None -> return (`NotFound pid) 
    | Some full -> return (`OK (format_full pid full))
