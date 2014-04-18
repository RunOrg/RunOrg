(* © 2014 RunOrg *)

open Std

type info = <
  id : I.t ;
  from : CId.t ;
  subject  : Unturing.t ;
  text     : Unturing.t option ;
  html     : Unturing.t option ; 
  audience : MailAccess.Audience.t ;
  custom : Json.t ;
  urls : String.Url.t list ;
>

let make id info = object
  method id = id
  method from = info # from
  method subject = info # subject
  method text = info # text
  method html = info # html
  method audience = info # audience
  method custom = info # custom
  method urls = info # urls 
end 

let get id = 
  let! info = Cqrs.MapView.get View.info id in 
  match info with None -> return None | Some info -> return (Some (make id info))
