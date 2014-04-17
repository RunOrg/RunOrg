(* © 2014 RunOrg *)

open Std

let create cid ~from ~subject ?text ?html audience = 

  let id = I.gen () in
  let text = match text with None -> `None | Some t -> `Raw t in
  let html = match html with None -> `None | Some t -> `Raw t in
  let subject = `Raw subject in 

  let! at = Store.append [ Events.created ~id ~cid ~from ~subject ~text ~html ~audience ] in

  return (id, at) 
