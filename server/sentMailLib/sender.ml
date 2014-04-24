(* © 2014 RunOrg *)

open Std

(* This module works under the assumption that only one instance of the sending 
   process may run at any given time. In a single-application context, this is
   guaranteed by the semantics of [Run.service].

   In a multi-application context... better get some cross-process mutex going, son.

   This module is the only one that pushes [`Sent] or [`SendingFailed] events to
   the stream. This means that, as long as the service is careful to synchronize
   with its own previous work, there will be no accidental double-sending. 
*)

let batch_size = 10

(* This function returns a batch of scheduled mail, if any. It synchronizes with 
   the server so that all the requests it appended are taken into account before
   selecting scheduled mail. 

   In other words: scheduled mail returned by this function has NOT been sent yet.
*)

let next_batch_sync : unit -> (#Cqrs.ctx, (Id.t * Mail.I.t * PId.t) list) Run.t = fun () -> 

  let! clock = Store.clock () in 
  Run.edit_context (fun ctx -> ctx # with_after clock) begin 
    let! list = Cqrs.StatusView.global_by_status ~limit:batch_size View.status `Scheduled in
    return (List.map (fun (db,(mid,pid)) -> db, mid, pid) list) 
  end 

(* This function constructs the subject and bodies of a mail by fetching the 
   appropriate corresponding data. Assumes to be run in the appropriate database. *)

type mail = < 
  to_     : string ; 
  from    : string ; 
  input   : (string, Json.t) Map.t ; 
  subject : string ; 
  text    : string option ;
  html    : string option ; 
  link    : Link.Root.t ; 
  wid     : I.t ;
>

type failure = 
  [ `NoInfoAvailable 
  | `NoSuchRecipient
  | `NoSuchSender    of PId.t 
  | `SubjectError    of string * int * int 
  | `TextError       of string * int * int 
  | `HtmlError       of string * int * int 
  | `Exception       of string 
  ]

let prepare_mail : Mail.I.t -> PId.t -> (Cqrs.ctx, (mail,failure) Std.result) Run.t = fun mid pid -> 

  let! data = Compose.scheduled mid pid in
  match data with Bad fail -> return (Bad fail) | Ok (wid, root, data) -> 

    let rendered = Compose.render data in
    
    return (Ok (object
      method from    = rendered # from
      method to_     = rendered # to_
      method input   = data # input
      method subject = rendered # subject
      method text    = rendered # text
      method html    = rendered # html 
      method link    = root
      method wid     = wid
    end))

(* Send e-mail by actually performing the MIME and SMTP magic dance. *)

let send : mail -> (#Cqrs.ctx, (unit,failure) Std.result) Run.t = fun mail ->
  return (Ok ()) 

(* Prepare an e-mail, send it, and write the appropriate status to the database.
   
   The only possible race condition would be: 
    - Process A reads the current stream clock: 42. 
    - Process B writes 'Sent' event to the stream for mail X. Clock becomes 43.
    - Process A waits on 42, views mail X as unsent, starts sending it.

   This cannot happen because only one process should run the mail service at 
   a given time. *)

let process (id,mid,pid) = 

  Run.edit_context (fun ctx -> ctx # with_db id) begin 

    let fail why = 
      let! _ = Store.append [ Events.sendingFailed ~mid ~pid ~why ] in
      return () 
    in

    let! prepare = prepare_mail mid pid in
    match prepare with Bad why -> fail why | Ok mail ->
      
      let! sent = send mail in
      match sent with Bad why -> fail why | Ok () ->
	
	let! _ = Store.append [ 
	  Events.sent ~id:(mail # wid) ~mid ~pid ~from:(mail # from) ~to_:(mail # to_) ~link:(mail # link)
	    ~input:(Json.Object (Map.to_list (mail # input))) 
	] in 

	return () 

  end

(* The core processing loop. 
   ========================= *)

let rec loop () = 

  let! list = next_batch_sync () in
  if list = [] then return () else

    let! () = List.M.iter process list in
    loop () 

(* The service definition and registration. 
   ======================================== *)

let service = Run.service "mailer" 
  (Run.of_call (fun () -> Cqrs.using O.config O.cqrs (loop ())) ())

let () = 
  Common.set_sender_service service
