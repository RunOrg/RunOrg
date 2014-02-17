(* © 2014 RunOrg *)

open Std

(* Short profile 
   ============= *)

type short = <
  id     : CId.t ;
  name   : String.Label.t ; 
  pic    : string ; 
  gender : [`F|`M] option ; 
>

let format_short cid short = object
  method id     = cid
  method name   = short # name
  method gender = short # gender
  method pic    = Gravatar.pic_of_email (String.Label.to_string (short # email))
end

(* Unfiltered access
   ================= *)

let get cid = 
  let! found = Cqrs.MapView.get View.short cid in 
  match found with None -> return None | Some short -> return (Some (format_short cid short))

let all ~limit ~offset = 
  let! list = Cqrs.MapView.all ~limit ~offset View.short in
  let! count = Cqrs.MapView.count View.short in 
  return (List.map (fun (cid,short) -> format_short cid short) list, count)

(* Filtered access 
   =============== *)

let search ?(limit=10) prefix = 
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
  List.M.filter_map get ids 
  

