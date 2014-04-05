(* © 2014 RunOrg *)

open Std

(* Retrieving forms 
   ================ *)

type info = <
  id       : I.t ;
  owner    : Owner.t ;
  label    : String.Label.t option ; 
  fields   : Field.t list ;
  custom   : Json.t ;
  audience : FormAccess.Audience.t ;
  empty    : bool ; 
> 

let make_info id info = object
  method id       = id
  method owner    = info # owner
  method label    = info # label
  method fields   = info # fields
  method custom   = info # custom
  method empty    = info # empty
  method audience = info # audience
end

let get id = 
  let! info = Cqrs.MapView.get View.info id in
  match info with None -> return None | Some info ->
    return (Some (make_info id info))

let list cid ~limit ~offset = 
  let! list = FormAccess.Map.list ~limit ~offset View.byAccess cid `Fill in
  List.M.filter_map get list
  
(* Retrieving filled forms
   ======================= *)

let get_filled id fid = 
  assert false


