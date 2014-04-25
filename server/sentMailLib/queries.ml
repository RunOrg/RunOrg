(* © 2014 RunOrg *)

open Std

(* Reading an individual sent (or unsent) mail
   =========================================== *)

type info = <
  mail : Mail.I.t ;
  to_  : PId.t ; 
  sent : Time.t option ; 
  opened  : Time.t option ; 
  subject : string ;
  html : string option ;
  text : string option ;
  status : Status.t ; 
>

let make mid pid status sent data = 
  let rendered = Compose.render data in 
  ( object
    method mail    = mid
    method to_     = pid
    method sent    = sent
    method opened  = None
    method subject = rendered # subject
    method text    = rendered # text
    method html    = rendered # html
    method status  = status 
  end : info ) 

let get_unsent mail pid = 
  let! preview = Compose.preview mail pid in 
  match preview with Bad f -> return (Bad f) | Ok data ->
    return (Ok (make (mail # id) pid `Preview None data))
      
let get_scheduled mid pid = 
  let! data = Compose.scheduled mid pid in
  match data with Bad f -> return (Bad f) | Ok (_,_,data) ->
    return (Ok (make mid pid `Scheduled None data))

let get_sent wid mid pid sent = 
  let! data = Compose.sent wid pid sent in
  match data with Bad f -> return (Bad f) | Ok data -> 
    return (Ok (make mid pid `Sent (Some (sent # sent)) data))

let get mail pid = 
  let  mid  = mail # id in
  let! info = Cqrs.MapView.get View.info (mid,pid) in
  match info with None -> get_unsent mail pid | Some info -> 
    match info # status with 
    | `Scheduled -> get_scheduled mid pid 
    | `Failed  f -> return (Bad (f # reason))
    | `Sent sent -> get_sent (info # wid) mid pid sent 

type stats = <
  prepared : int ;
  sent : int ;
  bounced : int ; 
  opened : int ; 
  clicked : int ; 
>

let stats mid = 
  assert false



