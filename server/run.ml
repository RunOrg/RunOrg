(* © 2014 RunOrg *)

open BatResult

(* Types, both public and private 
   ============================== *)

type thr = 
  | Fork of thr list Lazy.t 
  | Wait of thr Event.event
  | Raise of exn 
  | Yield of thr 

(* A thread is evaluated using: 
   - a context 
   - a successful return function (called on the result) 
   - a failed return function (called on the exception)

   The thread may call one of the two return functions directly, 
   and may return zero, one or more new threads to be added to the
   evaluation queue.    

   Such a function (usually either m or mFoo below) never raises
   exceptions, nor does the lazy evaluation of the returned [thr]  
   raise an exception. 

   Also, while the failed return function never
   raises exceptions either, the successful return function may 
   raise exceptions, and so should be defended against.
*)

type ('ctx,'value) t = 'ctx -> (exn -> string -> thr) -> ('value -> thr) -> thr

type ('ctx,'value) value  = ('ctx,'value) t
type 'ctx          effect = ('ctx,unit) t
type 'ctx          thread = ('ctx,unit) t

(* Exception handling 
   ================== *)

let trace_exceptions = false

let trace n bad exn trace = 
  if trace_exceptions then Log.trace "trace %s: %s" n (Printexc.to_string exn) ; 
  bad exn trace 

let bktrc n bad exn = 
  trace n bad exn (Printexc.get_backtrace ()) 

let catch n f x = 
  try Ok (f x) with exn -> let trace = Printexc.get_backtrace () in
			   if trace_exceptions then 
			     Log.trace "catch %s: %s\n%s" n (Printexc.to_string exn) trace ; 
			   Bad (fun bad -> bad exn trace)


(* Monad usage 
   =========== *)

let return x = fun ctx bad ok -> Fork (lazy [try ok x with exn -> bktrc "return" bad exn])   

let bind f m = fun ctx bad ok -> 
  m ctx bad (fun x -> 
    match catch "bind" f x with 
    | Ok  m -> m ctx bad ok 
    | Bad f -> f bad) 

let map  f m = fun ctx bad ok ->
  m ctx bad (fun x -> try ok (f x) with exn -> bktrc "map" bad exn)

let unwrap m = fun ctx bad ok -> 
  m ctx bad (fun m -> m ctx bad ok) 

(* Internal usage only *)
let (|>>) m f = map f m 

(* Context manipulation 
   ==================== *)

let context = fun ctx bad ok -> Fork (lazy [try ok ctx with exn -> bktrc "context" bad exn]) 

let with_context ctx m = fun _ bad ok -> m ctx bad ok

let edit_context f m = fun ctx bad ok -> 
  match catch "edit_context" f ctx with 
  | Ok  ctx -> m ctx bad ok
  | Bad f   -> f bad

(* Concurrency manipulation 
   ======================== *)

let nop = Fork (lazy [])

let yield m = fun ctx bad ok -> Yield (Fork (lazy [m ctx bad ok]))

let join a b f = fun ctx bad ok -> 

  let finish xa xb = match catch "join:finish" (f xa) xb with 
    | Bad f -> f bad 
    | Ok  m -> m ctx bad ok 
  in

  let ra = ref None and rb = ref None in 
  let ok_a xa = match !rb with 
    | None    -> ra := Some xa ; nop
    | Some xb -> finish xa xb
  and ok_b xb = match !ra with
    | None    -> rb := Some xb ; nop
    | Some xa -> finish xa xb
  in

  Fork (lazy [a ctx bad ok_a ; b ctx bad ok_b]) 

let fork onFail a b = fun ctx bad ok -> 
  let rec fail exn trace = 
    onFail exn ctx fail (fun () -> nop)
  in
  Fork (lazy [b ctx bad ok ; a ctx (trace "fork" fail) (fun _ -> nop)])

class ['ctx] joiner = object (self) 

  val mutable count    = 0
  val mutable after    = None

  method wait : ('ctx,unit) t = fun _ bad ok -> 
    if count = 0 then 
      try ok () with exn -> bktrc "joiner#wait" bad exn 
    else 
      ( after <- Some (bad,ok) ; nop )
	
  method start (m : ('ctx, unit) t) = 
    count <- count + 1 ;
    let emit_if_zero () = 
      count <- count - 1 ;
      if count = 0 then match after with 
        | None -> nop
        | Some (bad,ok) -> ( after <- None ; try ok () with exn -> bktrc "joiner#start:emit_if_zero" bad exn )
      else nop
    in
    fun ctx bad ok -> Fork (lazy [ (try ok () with exn -> bktrc "joiner#start" bad exn) ; 
				   m ctx bad emit_if_zero ]) 
      
end

class mutex = object (self)

  (* Functions in this queue will never throw. *)
  val waiting = Queue.create ()

  val mutable locked = false

  method lock : 'ctx 'a . ('ctx, 'a) t -> ('ctx, 'a) t = fun m ctx bad ok -> 

    let ok r = 
      if Queue.is_empty waiting then begin
	locked <- false ;
	ok r 
      end else begin
	let next = Queue.take waiting in
	Fork (lazy [ next () ; (try ok r with exn -> bktrc "mutex#lock" bad exn) ])
      end
    in
      
    if locked then begin 
      Queue.add (fun () -> m ctx bad ok) waiting ; nop
    end else begin 
      locked <- true ; m ctx bad ok
    end

  method if_unlocked : 'ctx 'a . ('ctx, 'a) t -> ('ctx, 'a) t = fun m ->
    if locked then self # lock m else m 
    
  method locked = locked

end 

class ['ctx] semaphore = object

  val mutable count = 0

  val waiting = Queue.create () 

  method count = count

  method take = fun (ctx : 'ctx) bad ok ->
    if count > 0 then 
      try     
	count <- count - 1 ; 
	ok () 
      with exn -> bktrc "semaphore#take" bad exn 
    else
      ( Queue.add (fun () -> try ok () with exn -> bktrc "semaphore#queue" bad exn) waiting ; nop )
    
  method give n = fun (ctx : 'ctx) bad ok ->

    count <- count + n ;

    let rec list i = 
      if i = 0 then [] else 
	if Queue.is_empty waiting then [] else
	  let head = Queue.take waiting in
	  head :: list (i-1)
    in
    
    let next = list n in
    count <- count - (List.length next) ;
    
    Fork (lazy ((try ok () with exn -> bktrc "semaphore#give" bad exn) :: List.map (fun f -> f ()) next))

end 

(* Utilities 
   ========= *)

let memo m = 
  let r = ref None in 
  fun c bad ok -> Fork (lazy [(
    match !r with 
    | Some (c',v) when c' == c -> (try ok v with exn -> bktrc "memo:hit" bad exn) 
    | _ -> m c bad (fun x -> r := Some (c,x) ; try ok x with exn -> bktrc "memo:miss" bad exn) 
  )])

let of_lazy l = fun _ bad ok -> Fork (lazy [try ok (Lazy.force l) with exn -> bktrc "of_lazy" bad exn])
let of_func f = fun _ bad ok -> Fork (lazy [try ok (f ()) with exn -> bktrc "of_func" bad exn])

let of_call f a = fun ctx bad ok -> 
  match catch "of_call" f a with 
  | Ok  m -> m ctx bad ok
  | Bad f -> f bad

let of_channel c = fun ctx bad ok ->
  let ev = Event.receive c in
  Wait (Event.wrap ev (fun v -> Fork (lazy [try ok v with exn -> bktrc "of_channel" bad exn])))

let to_channel c v = fun ctx bad ok ->
  let ev = Event.send c v in
  Wait (Event.wrap ev (fun () -> Fork (lazy [try ok () with exn -> bktrc "to_channel" bad exn])))

let on_failure f m = fun ctx bad ok -> 
  let bad exn _ = 
    match catch "on_failure" f exn with 
    | Ok  m -> m ctx bad ok
    | Bad f -> f bad
  in
  m ctx bad ok 

let finally f m = fun ctx bad ok ->
  let f () = try f () with exn -> Log.exn exn "Exception thrown in Run.finally" in
  let bad exn trace = f () ; bad exn trace in
  let ok x = f () ; ok x in
  m ctx bad ok 

let background f x = 
  let c = Event.new_channel () in
  let _ = Thread.create (fun x -> Event.sync (Event.send c (try Ok (f x) with exn -> Bad exn))) x in
  of_channel c |>> function 
  | Ok result -> result
  | Bad exn -> raise exn

(* List functions 
   ============== *)

module ForList = struct

  let map f l = fun ctx bad ok -> 
    if l = [] then try ok [] with exn -> bktrc "ForList.map" bad exn else 

      let failed = ref false in
      let bad exn trace = if !failed then nop else (failed := true ; bad exn trace) in 

      let list = List.map (fun x -> x, ref None) l in

      let num_unevaled = ref (List.length l) in
      let ok r y = 
	if !failed then nop else begin
	  if !r = None then decr num_unevaled ; 
	  r := Some y ;
	  if !num_unevaled > 0 then nop 
	  else ok (List.map 
		     (fun (x,r) -> match !r with Some y -> y | None -> assert false) 
		     list)
	end
      in

      Fork (lazy (List.map begin fun (x,r) -> 
	match catch "ForList.map:map" f x with 
	| Ok  m -> m ctx bad (ok r)
	| Bad f -> f bad
      end list))
	
  let filter_map f l = map f l |>> BatList.filter_map BatPervasives.identity
  let filter f l = filter_map (fun x -> bind (function true -> return (Some x) | false -> return None) (f x)) l
  let collect f l = map f l |>> List.concat 

  let rec find f = function 
    | []     -> return None
    | h :: t -> bind (function 
      | None -> find f t
      | some -> return some) (f h) 
      
  let rec fold_left f a = function
    | []     -> return a
    | h :: t -> bind (fun a -> fold_left f a t) (f a h) 

  let mfold f a l = bind (fold_left (fun a f -> f a) a) (map f l) 

  let iter_seq f l = 
    let rec aux = function 
      | [] -> return () 
      | h :: t -> bind (fun () -> aux t) (f h) 
    in aux l  
		       
  let iter f l = fun ctx bad ok -> 
    if l = [] then try ok () with exn -> bktrc "ForList.iter" bad exn else 

      let failed = ref false in
      let bad exn trace = if !failed then nop else (failed := true ; bad exn trace) in

      let r = ref (List.length l) in 
      let ok () = 
	if !failed then nop else ( decr r ; if !r = 0 then ok () else nop) 
      in

      Fork (lazy (List.map begin fun x -> 
	match catch "ForList.iter:map" f x with 
	| Ok  m -> m ctx bad ok
	| Bad f -> f bad
      end l))
	
  let exists pred l = 
    find (fun x -> pred x |>> (fun px -> if px then Some () else None)) l
    |>> BatOption.is_some

end

module ForOption = struct

  let map f = function 
    | None   -> (fun ctx bad ok -> try ok None with exn -> bktrc "ForOption.map" bad exn)
    | Some x -> (fun ctx bad ok -> match catch "ForOption.map" f x with 
      | Bad f -> f bad
      | Ok  m -> m ctx bad (fun y -> ok (Some y)))
      
  let bind f = function
    | None   -> (fun ctx bad ok -> try ok None with exn -> bktrc "ForOption.bind" bad exn)
    | Some x -> (fun ctx bad ok -> match catch "ForOption.bind" f x with 
      | Bad f -> f bad
      | Ok  m -> m ctx bad ok)

end

let loop f = 
  let rec loop () = f (yield (of_call loop ())) in loop () 

(* Evaluation 
   ========== *)

let eval ctx m = 

  let r       = ref None in 
  let ok  x   = r := Some x ; nop in 
  let bad exn trc = Raise exn in

  (* All active items (those returned by a [Fork]) are stored in this queue.
     This is where the main loop queries for new tasks to perform. *)
  let active  = Queue.create () in 

  let to_active = List.iter (fun task -> Queue.push task active) in 

  (* All delayed items (those returned by a [Yield]) are stored in this
     queue. The main loop will grab all tasks from this queue when the 
     active queue is empty. *)
  let delayed = Queue.create () in

  (* A list of all events (those returned by a [Wait]). The main loop
     will grab available tasks from this queue when the active queue is
     empty, and will block on this set when there is nothing left to 
     do (in order to save processing time). 

     These events are paired with an integer identifier (used for 
     removing them after querying them once), and return their 
     identifier in addition to the [thr].
  *)
  let events  = ref [] in

  (* The number of events handled so far (used for attributing identifiers
     to events. *)
  let eventCount = ref 0 in
  
  let add_event ev = 
    let id = !eventCount in 
    events := (id, Event.wrap ev (fun thr -> id, thr)) :: !events ;
    incr eventCount 
  in

  (* The last time events were polled. *)
  let last_event_poll = ref 0.0 in

  (* Never stay more than 500ms without polling events, unless the
     queues are getting to large. *)
  let should_poll_events () = 
    !events <> [] 
    && Queue.length active + Queue.length delayed < 100
    && Unix.gettimeofday () -. !last_event_poll > 500.
  in

  (* Processing a specific task, then processing whatever is left. *)
  let rec process = function   
    | Yield task -> Queue.push task delayed ; continue () 
    | Wait ev -> (match Event.poll ev with 
      | Some task -> process task 
      | None -> add_event ev ; continue ())
    | Fork tasks -> (match Lazy.force tasks with 
      | h :: t -> to_active t ; process h 
      | []     -> continue ())
    | Raise exn -> raise exn 

  (* Looks for a task to be executed, because the current processing 
     chain was broken. *) 
  and continue () = 
    if should_poll_events () then
      (ignore (poll_events ~block:false) ; continue ()) 
    else if not (Queue.is_empty active) then
      process (Queue.pop active)
    else if poll_events ~block:false then
      continue () 
    else if not (Queue.is_empty delayed) then
      (Queue.transfer delayed active ; continue ())
    else if poll_events ~block:true then 
      continue () 
    else
      () 

  (* Poll for any available events, remove them from the list. *)
  and poll_events ~block = 
    last_event_poll := Unix.gettimeofday () ;
    if !events = [] then false else      
      let rec extract accRead accWait = function 
	| [] -> events := accWait ; accRead
	| (k,h) :: t -> match Event.poll h with 
	  | None -> extract accRead ((k,h) :: accWait) t
	  | Some (_,thr) -> extract (thr :: accRead) accWait t 
      in
      match extract [] [] !events with
      | [] when block -> let k, thr = Event.select (List.map snd !events) in 
			 events := List.filter (fun (id,_) -> id <> k) !events ;
			 to_active ( thr :: extract [] [] !events ) ; 
			 true
      | list -> to_active list ; list <> []
  in

  process (m ctx bad ok) ;
  match !r with None -> assert false | Some result -> result

let start ?(exn_handler=(fun _ -> true)) ctx ms = 

  let retry m = fun ctx fail ok -> 
    let rec bad exn backtrace = 
      Log.error "Exception occurred in Run.start" ;
      Log.exn exn backtrace ;
      if exn_handler exn then 
	Yield (m ctx bad ok) 
      else
	fail exn backtrace
    in
    m ctx bad ok 
  in
  
  eval ctx (ForList.iter retry ms) 

(* Sleeping
   ======== *)

module S = Set.Make(struct
  type t = float * (unit -> unit)
  let compare (ta,_) (tb,_) = compare ta tb
end) 

(* A sorted set of (wake-up time, channel) pairs, and a wakeup thread id. *)
let sleep_wakeup_queue = ref (None, S.empty)
let sleep_wakeup_queue_mutex = Mutex.create () 

(* Perform an atomic update of the sleep queue. The argument function may be 
   called several times. *)
let rec update_sleep_wakeup_queue update = 
  let old_thread_id, old_set = !sleep_wakeup_queue in 
  let result, thread_id, set = update (old_thread_id, old_set) in
  Mutex.lock sleep_wakeup_queue_mutex ;
  let new_thread_id, new_set = !sleep_wakeup_queue in 
  let same = new_thread_id = old_thread_id && new_set == old_set in
  if same then sleep_wakeup_queue := (thread_id, set) ;
  Mutex.unlock sleep_wakeup_queue_mutex ; 
  if same then result else update_sleep_wakeup_queue update

(* The number of live wake-up threads. *)
let wakeup_threads = ref 0 

let sleep duration = 

  let channel = Event.new_channel () in
  let waketime = Unix.gettimeofday () +. duration /. 1000. in 
  
  let wake () = Event.sync (Event.send channel ()) in

  (* Code run by the thread. Waits until the next event, then wakes up 
     all the elements that should be woken up, IF it is still the 
     active thread. *)
  let rec wait_thread time = 

    incr wakeup_threads ; 

    let now = Unix.gettimeofday () in 
    let wake = max 0. (time -. now) in
    if wake > 0. then Thread.delay wake ;

    let infSet, supSet = update_sleep_wakeup_queue begin fun (thread_id_opt, set) ->
      if thread_id_opt <> Some Thread.(id (self ())) 
      then (S.empty,S.empty), thread_id_opt, set 
      else
	let now = Unix.gettimeofday () in 
	let supSet, infSet = S.partition (fun (time,_) -> time > now) set in 
	let empty = S.is_empty supSet in
	(infSet, supSet), (if empty then None else thread_id_opt), supSet
    end in

    S.iter (fun (_,wakeup) -> wakeup ()) infSet ; 

    decr wakeup_threads ; 

    try wait_thread (fst (S.min_elt supSet)) with Not_found -> () 

  in
  
  (* Add the wake-up event to the queue, and start a new wake-up thread if
     the current one is not active or will wake up too late. *)
  let () = update_sleep_wakeup_queue begin fun (thread_id_opt, set) -> 
  
    (* We only support up to 50ms precision on wake-ups. *)
    let lowest = try waketime +. 0.05 < fst (S.min_elt set) with Not_found -> true in
    let set = S.add (waketime, wake) set in 
    let tid = match thread_id_opt with 
      | Some tid when not lowest -> Some tid 
      | _ -> Some (Thread.(id (create wait_thread waketime))) in

    (), tid, set

  end in

  of_channel channel 

(* Services
   ======== *)

type service = {
  work : unit effect ;
  name : string ; 
  mutable running : bool ;
  mutable pinged : bool ;  
}

let service name work = { name ; work ; running = false ; pinged = false }

let ping service = 

  (* Possible states and transitions: 

     ping: 
       () -> (running) + thread
       (running) + thread -> (running,pinged) + thread
       (running,pinged) + thread -> (running,pinged) + thread

     work returns:
       (running) + thread -> ()
       (running,pinged) + thread -> (running) + thread

     work throws: 
       (running) + thread -> (running) + thread
       (running,pinged) + thread -> (running,pinged) + thread

  *)

  (* Runs 'work', then re-runs it again if 'pinged' is true when it finishes. 
     Lasts until 'pinged' is false after 'work' finishes, or 'work' raises
     an exception. *)
  let rec run : unit -> unit effect = fun () ->  
    bind 
      (fun () -> 
	if service.pinged then
	  ( service.pinged <- false ; run ())
	else
	  ( service.running <- false ; return ()))
      service.work
  in

  (* Runs 'run' once, and re-runs it if it throws an 
     exception. Returns when 'run' returns normally. *)
  let rec run_safe () = 
    on_failure (fun exn -> Log.exn exn ("In service " ^ service.name) ; run_safe ())
      (run ())
  in

  if service.running then return (service.pinged <- true) else begin    
    service.running <- true ; 
    fork 
      (fun exn -> return ()) (* <-- should not happen, run_safe never throws. *)
      (with_context () (run_safe ()))
      (return ())
  end
