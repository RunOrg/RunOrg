(* © 2014 RunOrg *)

open Std

(* Creating e-mail 
   =============== *)

(* Who is allowed to create new e-mails ? *)
let create_audience = Audience.admin 

let create cid ~from ~subject ?text ?html ?(custom=Json.Null) ?(urls=[]) ?self audience = 

  let id = I.gen () in
  let self = match self with None -> None | Some f -> Some (f id) in 
    
  let! allowed = Audience.is_member cid create_audience in 
  
  if not allowed then     
    let! ctx = Run.context in 
    return (`NeedAccess (ctx # db))
  else

    let! at = Store.append 
      [ Events.created ~id ~cid ~from ~subject ~text ~html ~audience ~custom ~urls ~self ] in
    
    return (`OK (id, at)) 
