(* © 2014 RunOrg *)

open Std

(* Reading an individual sent (or unsent) mail
   =========================================== *)

type info = <
  mail   : Mail.I.t ;
  to_    : PId.t ; 
  view   : Compose.rendered ;
  sent   : Time.t option ; 
  opened : Time.t option ; 
  status : Status.t ; 
>

let make mid pid status sent data = 
  let rendered = Compose.render data in 
  ( object
    method mail   = mid
    method to_    = pid
    method sent   = sent
    method opened = None
    method view   = rendered
    method status = status 
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
  let! data = Compose.sent wid sent in
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

(* Statistics generation 
   ===================== *)

type stats = <
  scheduled : int ;
  sent : int ;
  failed : int ; 
  opened : int ;
  clicked : int ; 
>

let stats pid mid = 

  (* Mail should exist... *)
  let! mail = Mail.get mid in 
  match mail with None -> return (`NoSuchMail mid) | Some mail -> 

    (* ...and be visible. *)
    let! access = Mail.Access.compute pid (mail # audience) in 
    if not (Set.mem `View access) then return (`NoSuchMail mid) else
      if not (Set.mem `Admin access) then return (`NeedAdmin mid) else
	
	let! clock = Cqrs.MapView.get View.last mid in
	let! stats = Cqrs.HardStuffCache.get Stats.compute mid (Option.default Cqrs.Clock.empty clock) in

	return (`OK stats) 

(* Following links 
   =============== *)

type link = <
  id   : I.t ;
  mid  : Mail.I.t ;
  pid  : PId.t ;
  link : [ `Self of String.Url.t | `Tracker | `Url of int * String.Url.t ] ;
  auth : bool ;
>

let link ln = 

  let! info = Cqrs.MapView.get View.byLinkRoot (Link.root ln) in
  match info with None -> return `NotFound | Some (wid,mid,pid) -> 

    let! wave = Cqrs.MapView.get View.wave wid in 
    match wave with None -> return `NotFound | Some wave ->

      let link = match Link.what ln with
	| `Track  -> Some `Tracker
	| `Self   -> Option.map (fun ln -> `Self ln) (wave # self)
	| `Auth i 
	| `View i -> (try Some (`Url (i, List.at (wave # urls) i)) with _ -> None) in

      let auth = match Link.what ln with
	| `Self 
	| `Auth _ -> true
	| `Track
	| `View _ -> false in

      match link with None -> return `NotFound | Some link  ->
	
	return (`OK (object
	  method id = wid
	  method mid = mid
	  method pid = pid
	  method link = link
	  method auth = auth
	end))
