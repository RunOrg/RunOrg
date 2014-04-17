(* © 2014 RunOrg *)

open Std

type info = <
  id : I.t ;
  from : CId.t ;
  subject : String.Label.t ;
  text : string option ;
  html : String.Rich.t option ;
  audience : MailAccess.Audience.t ;
>

let make id info = object
  method id = id
  method from = info # from
  method subject = info # subject
  method text = info # text
  method html = info # html
  method audience = info # audience
end 

let get id = 
  let! info = Cqrs.MapView.get View.info id in 
  match info with None -> return None | Some info -> return (Some (make id info))
