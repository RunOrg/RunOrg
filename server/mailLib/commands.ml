(* © 2014 RunOrg *)

open Std

(* Creating e-mail 
   =============== *)

(* Who is allowed to create new e-mails ? *)
let create_audience = Audience.admin 

let create pid ~from ~subject ?text ?html ?(custom=Json.Null) ?(urls=[]) ?self audience = 

  let id = I.gen () in
  let self = match self with None -> None | Some f -> Some (f id) in 
    
  let! allowed = Audience.is_member pid create_audience in 
  
  if not allowed then     
    let! ctx = Run.context in 
    return (`NeedAccess (ctx # db))
  else

    let! view_sender = Person.can_view_full pid from in
    if not view_sender then return (`NeedViewProfile from) else

      let! at = Store.append 
	[ Events.created ~id ~pid ~from ~subject ~text ~html ~audience ~custom ~urls ~self ] in
      
      return (`OK (id, at)) 
