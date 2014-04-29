(* © 2014 RunOrg *)

open Std

(* A few data formatting utilities *)

let email_address person = object
  val name = Option.map String.Label.to_string (person # name) 
  method name = name
  val email = String.Label.to_string (person # email) 
  method email = email
end

let person_json person = 
  Json.Object [ 
    "label",      String.Label.to_json (person # label) ; 
    "name",       Json.of_opt String.Label.to_json (person # name) ;
    "givenName",  Json.of_opt String.Label.to_json (person # givenName) ;
    "familyName", Json.of_opt String.Label.to_json (person # familyName) ;
    "email",      String.Label.to_json (person # email) ; 
  ]

(* Raw data 
   ======== *)

type data = < 
  from    : < name : string option ; email : string > ;
  to_     : < name : string option ; email : string > ;
  input   : (string, Json.t) Map.t ;
  subject : Unturing.script ;
  text    : Unturing.script option ;
  html    : Unturing.script option ; 
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

exception PrepareFailure of failure 

(* There is no need to keep the URLs in the input data, they can be rebuilt from 
   the wave URLs and the link root. *)

let add_links db root self urls input = 
  List.fold_left (fun m (k,v) -> Map.add k v m) input [
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
  ] 

let remove_links input = 
  List.fold_left (fun m k -> Map.remove k m) input [ "track" ; "self" ; "urls" ; "auth" ]

(* Generic function, does not query the database, returns [data]. 
   If no link root is provided (as is the case for previews), uses the
   actual URLs. *)
let prepare ~sender ~self ~person ?root ~db ~urls ~custom ~subject ~text ~html = 
  
    let  from   = email_address sender in 
    let  to_    = email_address person in 

    let  input  = Map.of_list [
      "to",     person_json person ;
      "from",   person_json sender  ; 
      "custom", custom ; 
    ] in

    let input = add_links db root self urls input in 

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

    (* Needed for filling the 'person' side of the template. *)
    let! person = Person.full cid in 
    let  person = match person with None -> raise (PrepareFailure `NoSuchRecipient) | Some c -> c in 

    (* Needed for filling the 'sender' side of the template. *)
    let  scid   = mail # from in 
    let! sender = Person.full scid in
    let  sender = match sender with None -> raise (PrepareFailure (`NoSuchSender scid)) | Some s -> s in 

    let! ctx    = Run.context in 
    let  db     = ctx # db in 
    
    return (prepare ~person ~sender ~db ?root:None ~self:(mail # self)
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
       persons or forget checking for person existence before adding to a group. Better
       safe than sorry. *)

    (* Needed for getting the wave id and the position of the person in the wave. *)
    let! sendinfo = Cqrs.MapView.get View.info (mid, cid) in
    let  sendinfo = match sendinfo with None -> raise (PrepareFailure `NoInfoAvailable) | Some s -> s in  
    let  nth      = sendinfo # pos in   

    (* Needed for getting all the saved information to build the mail. *)
    let  wid  = sendinfo # wid in 
    let! wave = Cqrs.MapView.get View.wave wid in
    let  wave = match wave with None -> raise (PrepareFailure `NoInfoAvailable) | Some w -> w in

    (* Needed for filling the 'person' side of the template. *)
    let! person = Person.full cid in 
    let  person = match person with None -> raise (PrepareFailure `NoSuchRecipient) | Some c -> c in 

    (* Needed for filling the 'sender' side of the template. *)
    let  scid   = wave # from in 
    let! sender = Person.full scid in
    let  sender = match sender with None -> raise (PrepareFailure (`NoSuchSender scid)) | Some s -> s in 

    let! ctx    = Run.context in 
    let  db     = ctx # db in 

    let  root   = Link.Root.make wid nth in 

    match
      prepare ~person ~sender ~db ~root ~self:(wave # self)
	~custom:(wave # custom) ~urls:(wave # urls) ~subject:(wave # subject)  
	~html:(wave # html) ~text:(wave # text) 
    with
    | Ok data -> return (Ok (wid, root, data))
    | Bad fail -> return (Bad fail)
      
  end

(* Read data from a sent mail. *)
let sent wid sent = 

  let handle_failure = function 
    | PrepareFailure reason -> return (Bad reason)
    | exn -> return (Bad (`Exception (Printexc.to_string exn)))
  in

  Run.on_failure handle_failure begin 
  
    (* The wave should ALWAYS exist. *)
    let! wave = Cqrs.MapView.get View.wave wid in
    let  wave = match wave with None -> raise (PrepareFailure `NoInfoAvailable) | Some w -> w in

    let input = match sent # input with 
      | Json.Object list -> Map.of_list list
      | _ -> Map.empty (* This should not happen. *)
    in

    let subject = 
      match Unturing.compile (wave # subject # script) (wave # subject # inline) with 
      | `SyntaxError (w,l,c) -> raise (PrepareFailure (`SubjectError (w,l,c)))
      | `OK script -> script
    in

    let text =
      match wave # text with None -> None | Some text -> 
	match Unturing.compile (text # script) (text # inline) with 
	| `SyntaxError (w,l,c) -> raise (PrepareFailure (`SubjectError (w,l,c)))
	| `OK script -> Some script
    in 

    let html =
      match wave # html with None -> None | Some html -> 
	match Unturing.compile (html # script) (html # inline) with 
	| `SyntaxError (w,l,c) -> raise (PrepareFailure (`SubjectError (w,l,c)))
	| `OK script -> Some script
    in 

    let! ctx    = Run.context in 
    let  db     = ctx # db in 

    return (Ok (object
      method from    = sent # from
      method to_     = sent # to_
      method input   = add_links db (Some (sent # link)) (wave # self) (wave # urls) input
      method subject = subject
      method text    = text
      method html    = html 
    end : data))

  end

(* Rendering 
   ========= *)

type rendered = <
  from    : < name : string option ; email : string > ;
  to_     : < name : string option ; email : string > ;
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

