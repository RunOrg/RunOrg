(* © 2013 RunOrg *)

open BatResult

(* Types, both public and private 
   ============================== *)

type thr = 
  | Fork of thr list Lazy.t 
  | Wait of thr Event.event
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

type ('ctx,'value) t = 'ctx -> (exn -> thr) -> ('value -> thr) -> thr

type ('ctx,'value) value  = ('ctx,'value) t
type 'ctx          effect = ('ctx,unit) t
type 'ctx          thread = ('ctx,unit) t

(* Monad usage 
   =========== *)

let return x = fun ctx bad ok -> Fork (lazy [try ok x with exn -> bad exn])   

let bind f m = fun ctx bad ok -> 
  m ctx bad (fun x -> 
    match catch f x with 
    | Ok  m   -> m ctx bad ok 
    | Bad exn -> bad exn) 

let map  f m = fun ctx bad ok ->
  m ctx bad (fun x -> try ok (f x) with exn -> bad exn)

let unwrap m = fun ctx bad ok -> 
  m ctx bad (fun m -> m ctx bad ok) 

(* Internal usage only *)
let (|>>) m f = map f m 

(* Context manipulation 
   ==================== *)

let context = fun ctx bad ok -> Fork (lazy [try ok ctx with exn -> bad exn]) 

let with_context ctx m = fun _ bad ok -> m ctx bad ok

let edit_context f m = fun ctx bad ok -> 
  match catch f ctx with 
  | Ok  ctx -> m ctx bad ok
  | Bad exn -> bad exn

(* Concurrency manipulation 
   ======================== *)

let nop = Fork (lazy [])

let yield m = fun ctx bad ok -> Yield (Fork (lazy [m ctx bad ok]))

let join a b f = fun ctx bad ok -> 

  let finish xa xb = match catch (f xa) xb with 
    | Bad exn -> bad exn 
    | Ok  m   -> m ctx bad ok 
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

let fork a b = fun ctx bad ok -> 
  Fork (lazy [b ctx bad ok ; a ctx (fun _ -> nop) (fun _ -> nop)])

class ['ctx] joiner = object (self) 

  val mutable count    = 0
  val mutable after    = None

  method wait : ('ctx,unit) t = fun _ bad ok -> 
    if count = 0 then 
      try ok () with exn -> bad exn 
    else 
      ( after <- Some (bad,ok) ; nop )
	
  method start (m : ('ctx, unit) t) = 
    count <- count + 1 ;
    let emit_if_zero () = 
      count <- count - 1 ;
      if count = 0 then match after with 
        | None -> nop
        | Some (bad,ok) -> ( after <- None ; try ok () with exn -> bad exn )
      else nop
    in
    fun ctx bad ok -> Fork (lazy [ (try ok () with exn -> bad exn) ; m ctx bad emit_if_zero ]) 
      
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
	Fork (lazy [ next () ; (try ok r with exn -> bad exn) ])
      end
    in
      
    if locked then begin 
      Queue.add (fun () -> m ctx bad ok) waiting ; nop
    end else begin 
      locked <- true ; m ctx bad ok
    end

  method if_unlocked : 'ctx 'a . ('ctx, 'a) t -> ('ctx, 'a) t = fun m ->
    if locked then self # lock m else m 
    
end 

class ['ctx] semaphore = object

  val mutable count = 0

  val waiting = Queue.create () 

  method count = count

  method take = fun (ctx : 'ctx) bad ok ->
    count <- count - 1 ;     
    if count >= 0 then try ok () with exn -> bad exn else
      ( Queue.add (fun () -> try ok () with exn -> bad exn) waiting ; nop )
    
  method give n = fun (ctx : 'ctx) bad ok ->
    count <- count + n ;

    let rec list n = 
      if n = 0 then [] else 
	if Queue.is_empty waiting then [] else
	  Queue.take waiting :: list (n-1)
    in
    
    let next = list n in
    count <- count - (List.length next) ;
    
    Fork (lazy ((try ok () with exn -> bad exn) :: List.map (fun f -> f ()) next))

end 

(* Utilities 
   ========= *)

let memo m = 
  let r = ref None in 
  fun c bad ok -> Fork (lazy [(
    match !r with 
    | Some (c',v) when c' == c -> (try ok v with exn -> bad exn) 
    | _ -> m c bad (fun x -> r := Some (c,x) ; ok x) 
  )])

let of_lazy l = fun _ bad ok -> Fork (lazy [try ok (Lazy.force l) with exn -> bad exn])
let of_func f = fun _ bad ok -> Fork (lazy [try ok (f ()) with exn -> bad exn])

let of_call f a = fun ctx bad ok -> 
  match catch f a with 
  | Ok  m   -> m ctx bad ok
  | Bad exn -> bad exn

let of_channel c = fun ctx bad ok ->
  let ev = Event.receive c in
  Wait (Event.wrap ev (fun v -> Fork (lazy [try ok v with exn -> bad exn])))

(* List functions 
   ============== *)

module ForList = struct

  let map f l = fun ctx bad ok -> 
    if l = [] then try ok [] with exn -> bad exn else 

      let failed = ref false in
      let bad exn = if !failed then nop else (failed := true ; bad exn) in 

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
	match catch f x with 
	| Ok  m   -> m ctx bad (ok r)
	| Bad exn -> bad exn
      end list))
	
  let filter_map f l = map f l |>> BatList.filter_map BatPervasives.identity
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
		       
  let iter f l = fun ctx bad ok -> 
    if l = [] then try ok () with exn -> bad exn else 

      let failed = ref false in
      let bad exn = if !failed then nop else (failed := true ; bad exn) in

      let r = ref (List.length l) in 
      let ok () = 
	if !failed then nop else ( decr r ; if !r = 0 then ok () else nop) 
      in

      Fork (lazy (List.map begin fun x -> 
	match catch f x with 
	| Ok  m   -> m ctx bad ok
	| Bad exn -> bad exn
      end l))
	
  let exists pred l = 
    find (fun x -> pred x |>> (fun px -> if px then Some () else None)) l
    |>> BatOption.is_some

end

module ForOption = struct

  let map f = function 
    | None   -> (fun ctx bad ok -> try ok None with exn -> bad exn)
    | Some x -> (fun ctx bad ok -> match catch f x with 
      | Bad exn -> bad exn
      | Ok  m   -> m ctx bad (fun y -> ok (Some y)))
      
  let bind f = function
    | None   -> (fun ctx bad ok -> try ok None with exn -> bad exn)
    | Some x -> (fun ctx bad ok -> match catch f x with 
      | Bad exn -> bad exn
      | Ok  m   -> m ctx bad ok)

end

let loop f = 
  let rec loop () = f (yield (of_call loop ())) in loop () 

(* Evaluation 
   ========== *)

let eval ctx m = 

  let r       = ref None in 
  let ok  x   = r := Some x ; nop in 
  let bad exn = raise exn in

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

  let status () = Log.trace "Active: %d | Delayed: %d | Waiting: %d" 
    (Queue.length active) (Queue.length delayed) (List.length !events) in

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

  (* Looks for a task to be executed, because the current processing 
     chain was broken. *) 
  and continue () = 
    status () ;
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

let start ctx ms = 

  let retry m = fun ctx _ ok -> 
    let rec bad exn = 
      Log.error "Run.start: %s" (Printexc.to_string exn) ; 
      Yield (m ctx bad ok) 
    in
    m ctx bad ok 
  in
  
  eval ctx (ForList.iter retry ms) 

let sleep duration = 
  let channel = Event.new_channel () in
  let _ = Thread.create 
    (fun d -> 
      Thread.delay d ; 
      Event.sync (Event.send channel ())) 
    (duration /. 1000.) in
  of_channel channel 
