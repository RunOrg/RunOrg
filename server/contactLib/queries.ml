(* © 2014 RunOrg *)

open Std

type short = <
  id     : CId.t ;
  name   : string ;
  pic    : string ; 
  gender : [`F|`M] option ; 
>

let get cid = 
  let! found = Cqrs.MapView.get View.short cid in 
  match found with None -> return None | Some short -> return (Some (object
    method id     = cid
    method name   = short # name
    method gender = short # gender
    method pic    = Gravatar.pic_of_email (short # email)
  end))
