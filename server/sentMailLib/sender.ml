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

let next_batch_sync : unit -> (#Cqrs.ctx, (Id.t * Mail.I.t * CId.t) list) Run.t = fun () -> 

  let! clock = Store.clock () in 
  Run.edit_context (fun ctx -> ctx # with_after clock) begin 
    let! list = Cqrs.StatusView.global_by_status ~limit:batch_size View.status `Scheduled in
    return (List.map (fun (db,(mid,cid)) -> db, mid, cid) list) 
  end 

(* A few data formatting utilities *)

let email_address contact = 
  let email = String.Label.to_string (contact # email) in 
  match contact # fullname with None -> email | Some name ->
    !! "%S <%s>" (String.Label.to_string name) email

let contact_json contact = 
  Json.Object [ 
    "name",      String.Label.to_json (contact # name) ; 
    "fullname",  Json.of_opt String.Label.to_json (contact # fullname) ;
    "firstname", Json.of_opt String.Label.to_json (contact # firstname) ;
    "lastname",  Json.of_opt String.Label.to_json (contact # lastname) ;
    "email",     String.Label.to_json (contact # email) ; 
  ]

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
  | `NoSuchContact 
  | `NoSuchSender    of CId.t 
  | `SubjectError    of string * int * int 
  | `TextError       of string * int * int 
  | `HtmlError       of string * int * int 
  | `Exception       of string 
  ]

exception PrepareFailure of failure 

let prepare_mail : Mail.I.t -> CId.t -> (Cqrs.ctx, (mail,failure) Std.result) Run.t = fun mid cid -> 

  let handle_failure = function 
    | PrepareFailure reason -> return (Bad reason)
    | exn -> return (Bad (`Exception (Printexc.to_string exn)))
  in

  Run.on_failure handle_failure begin 

    (* The error conditions below should not happen in a normal database situation, BUT... 
       We never know how the system requirements will evolve. Maybe we'll allow deleting
       contacts or forget checking for contact existence before adding to a group. Better
       safe than sorry. *)

    (* Needed for getting the wave id and the position of the contact in the wave. *)
    let! sendinfo = Cqrs.MapView.get View.info (mid, cid) in
    let  sendinfo = match sendinfo with None -> raise (PrepareFailure `NoInfoAvailable) | Some s -> s in  
    let  nth      = sendinfo # pos in   

    (* Needed for getting all the saved information to build the mail. *)
    let  wid  = sendinfo # wid in 
    let! wave = Cqrs.MapView.get View.wave wid in
    let  wave = match wave with None -> raise (PrepareFailure `NoInfoAvailable) | Some w -> w in

    (* Needed for filling the 'contact' side of the template. *)
    let! contact = Contact.full cid in 
    let  contact = match contact with None -> raise (PrepareFailure `NoSuchContact) | Some c -> c in 

    (* Needed for filling the 'sender' side of the template. *)
    let  scid   = wave # from in 
    let! sender = Contact.full scid in
    let  sender = match sender with None -> raise (PrepareFailure (`NoSuchSender scid)) | Some s -> s in 

    let! ctx    = Run.context in 
    let  db     = ctx # db in 

    let  from   = email_address sender in 
    let  to_    = email_address contact in 

    let  root   = Link.Root.make wid nth in 

    let  input  = Map.of_list [
      "to",     contact_json contact ;
      "from",   contact_json sender  ; 
      "custom", wave # custom ; 
      "track",  Link.url db (Link.track root) ; 
      "self",   (if wave # self = None then Json.Null else Link.url db (Link.self root)) ;
      "urls",   Json.Array (List.mapi (fun i _ -> Link.url db (Link.view root i)) (wave # urls)) ;
      "auth",   Json.Array (List.mapi (fun i _ -> Link.url db (Link.auth root i)) (wave # urls)) ;  
    ] in 

    let subject = 
      match Unturing.compile (wave # subject # script) (wave # subject # inline) with 
      | `SyntaxError (w,l,c) -> raise (PrepareFailure (`SubjectError (w,l,c)))
      | `OK script -> Unturing.template ~html:false script input 
    in

    let text =
      match wave # text with None -> None | Some text -> 
	match Unturing.compile (text # script) (text # inline) with 
	| `SyntaxError (w,l,c) -> raise (PrepareFailure (`SubjectError (w,l,c)))
	| `OK script -> Some (Unturing.template ~html:false script input)
    in 

    let html =
      match wave # html with None -> None | Some html -> 
	match Unturing.compile (html # script) (html # inline) with 
	| `SyntaxError (w,l,c) -> raise (PrepareFailure (`SubjectError (w,l,c)))
	| `OK script -> Some (Unturing.template ~html:false script input)
    in 
    
    return (Ok (object
      method from    = from
      method to_     = to_
      method input   = input
      method subject = subject
      method text    = text
      method html    = html 
      method link    = root
      method wid     = wid
    end))
    		    
  end

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

let process (id,mid,cid) = 

  Run.edit_context (fun ctx -> ctx # with_db id) begin 

    let fail why = 
      let! _ = Store.append [ Events.sendingFailed ~mid ~cid ~why ] in
      return () 
    in

    let! prepare = prepare_mail mid cid in
    match prepare with Bad why -> fail why | Ok mail ->
      
      let! sent = send mail in
      match sent with Bad why -> fail why | Ok () ->
	
	let! _ = Store.append [ 
	  Events.sent ~id:(mail # wid) ~mid ~cid ~from:(mail # from) ~to_:(mail # to_) ~link:(mail # link)
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
