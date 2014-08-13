(* © 2014 RunOrg *)

open Std

(* Scheduling e-mail to be sent.
   ============================= *)

(* Who is allowed to send e-mail ? *)
let send_audience = Audience.admin 

let batch_size = 100

let send pid mid gid = 
  let! allowed = Audience.is_member pid send_audience in 
  
  if not allowed then     
    let! ctx = Run.context in 
    return (`NeedAccess (ctx # db))
  else

    let! info = Mail.get mid in 
    match info with None -> return (`NoSuchMail mid) | Some info -> 

      let! group = Group.get pid gid in 
      match group with None -> return (`NoSuchGroup gid) | Some group -> 

	match group # count with 
	| None -> return (`NeedList gid) 
	| Some 0 -> return (`GroupEmpty gid) 
	| Some count -> 

	  let id = I.gen () in
	  
	  let rec batches acc offset = 
	    if offset > count then return acc else
	      let! list = Group.list_force ~limit:batch_size ~offset gid in 
	      batches 
		((Events.batchScheduled ~id ~mid ~pos:offset ~list) :: acc)
		(offset + batch_size) in 
	  
	  let! batches = batches [] 0 in 
	  
	  let groupWaveCreate = Events.groupWaveCreated ~id ~pid ~mid ~gid 
	    ~from:(info # from) 
	    ~subject:(info # subject) 
	    ~text:(info # text)
	    ~html:(info # html)
	    ~urls:(info # urls)
	    ~self:(info # self) 
	    ~custom:(info # custom) in
	  
	  let! clock = Store.append (groupWaveCreate :: batches) in

	  return (`OK (id, count, clock))

let sendToPeople pid mid pids = 
  let! allowed = Audience.is_member pid send_audience in 
  
  if not allowed then     
    let! ctx = Run.context in 
    return (`NeedAccess (ctx # db))
  else

    let! info = Mail.get mid in 
    match info with None -> return (`NoSuchMail mid) | Some info -> 

      let id = I.gen () in
      
      let waveCreate = Events.personWaveCreated ~id ~pid ~mid
	~from:(info # from) 
	~subject:(info # subject) 
	~text:(info # text)
	~html:(info # html)
	~urls:(info # urls)
	~self:(info # self) 
	~custom:(info # custom) in
      
      let count = List.length pids in
      let batch = Events.batchScheduled ~id ~mid ~pos:0 ~list:pids in
      
      let! clock = Store.append [ waveCreate ; batch ] in
      
      return (`OK (id, count, clock))

(* Following links 
   =============== *)

let follow ln ip = 

  let! ctx = Run.context in 

  let! link = Queries.link ln in 
  match link with `NotFound -> return (`NotFound (ln, ctx # db)) | `OK info -> 

    let! auth = 
      if info # auth then 
	let! tok = Token.create (`Person (ctx # db, info # pid)) in
	return (Some tok) 
      else return None 
    in

    let result = match info # link with 
      | `Tracker      -> `Track
      | `Self    url
      | `Url (_, url) -> match auth with None -> `Link url | Some tok -> `Auth (tok,url) in

    let link = match info # link with 
      | `Tracker   -> `Tracker
      | `Self _    -> `Self
      | `Url (i,_) -> `Url i in

    let! _ = Store.append [
      Events.linkFollowed 
	~id:(info # id) ~mid:(info # mid) ~pid:(info # pid) 
	~auto:(result = `Track) ~ip ~auth ~link
    ] in

    return result
