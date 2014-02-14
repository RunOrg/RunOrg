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
  assert false
