(* © 2014 RunOrg *)

open Std

(* Creating e-mail 
   =============== *)

(* Who is allowed to create new e-mails ? *)
let create_audience = Audience.admin 

let create cid ~from ~subject ?text ?html audience = 

  let! allowed = Audience.is_member cid create_audience in 
  
  if not allowed then     
    let! ctx = Run.context in 
    return (`NeedAccess (ctx # db))
  else

    let id = I.gen () in
    let text = match text with None -> `None | Some t -> `Raw t in
    let html = match html with None -> `None | Some t -> `Raw t in
    let subject = `Raw subject in 
    
    let! at = Store.append [ Events.created ~id ~cid ~from ~subject ~text ~html ~audience ] in
    
    return (`OK (id, at)) 
