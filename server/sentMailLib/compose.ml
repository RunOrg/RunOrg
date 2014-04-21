(* © 2014 RunOrg *)

open Std

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

(* Raw data 
   ======== *)

type data = < 
  from    : string ;
  to_     : string ;
  input   : (string, Json.t) Map.t ;
  subject : Unturing.script ;
  text    : Unturing.script option ;
  html    : Unturing.script option ; 
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

(* Generic function, does not query the database, returns [data]. 
   If no link root is provided (as is the case for previews), uses the
   actual URLs. *)
let prepare ~sender ~self ~contact ?root ~db ~urls ~custom ~subject ~text ~html = 
  
    let  from   = email_address sender in 
    let  to_    = email_address contact in 

    let  input  = Map.of_list [
      "to",     contact_json contact ;
      "from",   contact_json sender  ; 
      "custom", custom ; 
      "track",  (match root with 
      | None      -> Json.String "void(0)" 
      | Some root -> Link.url db (Link.track root)) ; 
      "self",   (match root with 
      | None      -> Json.of_opt String.Url.to_json self 
      | Some root -> if self = None then Json.Null else Link.url db (Link.self root)) ;
      "urls",   (match root with 
      | None      -> Json.Array (List.map String.Url.to_json urls) 
      | Some root -> Json.Array (List.mapi (fun i _ -> Link.url db (Link.view root i)) urls)) ;
      "auth",   (match root with 
      | None      -> Json.Array (List.map String.Url.to_json urls)
      | Some root -> Json.Array (List.mapi (fun i _ -> Link.url db (Link.auth root i)) urls)) ;
    ] in 

    let subject = 
      match Unturing.compile (subject # script) (subject # inline) with 
      | `SyntaxError (w,l,c) -> raise (PrepareFailure (`SubjectError (w,l,c)))
      | `OK script -> script
    in

    let text =
      match text with None -> None | Some text -> 
	match Unturing.compile (text # script) (text # inline) with 
	| `SyntaxError (w,l,c) -> raise (PrepareFailure (`SubjectError (w,l,c)))
	| `OK script -> Some script
    in 

    let html =
      match html with None -> None | Some html -> 
	match Unturing.compile (html # script) (html # inline) with 
	| `SyntaxError (w,l,c) -> raise (PrepareFailure (`SubjectError (w,l,c)))
	| `OK script -> Some script
    in 

    Ok (object
      method from = from
      method to_  = to_
      method input = input
      method subject = subject
      method text = text
      method html = html 
    end : data)

(* Read preview data *)
let preview (mail:Mail.info) cid = 

  let handle_failure = function 
    | PrepareFailure reason -> return (Bad reason)
    | exn -> return (Bad (`Exception (Printexc.to_string exn)))
  in

  Run.on_failure handle_failure begin 

    (* Needed for filling the 'contact' side of the template. *)
    let! contact = Contact.full cid in 
    let  contact = match contact with None -> raise (PrepareFailure `NoSuchContact) | Some c -> c in 

    (* Needed for filling the 'sender' side of the template. *)
    let  scid   = mail # from in 
    let! sender = Contact.full scid in
    let  sender = match sender with None -> raise (PrepareFailure (`NoSuchSender scid)) | Some s -> s in 

    let! ctx    = Run.context in 
    let  db     = ctx # db in 
    
    return (prepare ~contact ~sender ~db ?root:None ~self:(mail # self)
	      ~custom:(mail # custom) ~urls:(mail # urls) ~subject:(mail # subject)  
	      ~html:(mail # html) ~text:(mail # text))

  end

(* Read data from a scheduled mailing wave. *)
let scheduled mid cid = 

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

    let  root   = Link.Root.make wid nth in 

    match
      prepare ~contact ~sender ~db ~root ~self:(wave # self)
	~custom:(wave # custom) ~urls:(wave # urls) ~subject:(wave # subject)  
	~html:(wave # html) ~text:(wave # text) 
    with
    | Ok data -> return (Ok (wid, root, data))
    | Bad fail -> return (Bad fail)
      
  end

(* Implement later. *)
let sent mid cid = 
  assert false

(* Rendering 
   ========= *)

type rendered = <
  from    : string ;
  to_     : string ;
  subject : string ;
  text    : string option ;
  html    : string option ;
>

let render (data:data) = object
  method from    = data # from
  method to_     = data # to_
  method subject = Unturing.template ~html:false (data # subject) (data # input)
  method text    = match data # text with None -> None | Some script -> 
    Some (Unturing.template ~html:false script (data # input))
  method html    = match data # html with None -> None | Some script ->
    Some (Unturing.template ~html:true script (data # input))
end

