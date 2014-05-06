open Std
open Common

let projection_run_functions = ref []

(* Projection methods : public side
   ================================ *)

(* Projections are a NASTY piece of work. 
   
   They source events of different types from multiple streams, so 
   it is impossible to keep track of all the individual streams that
   are followed by a projection from within the projection itself 
   (except by dropping the event type, at which point it becomes
   impossible to de-duplicate streams). 

   Because of this, projections have to rely on streams to perform
   de-duplication themselves. Each stream will remember all 
   projections that are following it, and use a hash table to store
   event processors (registered ith Stream.track) for each view.
*)

type t = {

  (* These two values are provided during initialization. *)
  name : string ;
  config : SqlConnection.config ; 

  (* A list of all views (kind, name and version number) that
     were registered in this projection. *)
  mutable contents : (string * int) list ;

  (* These values are computed once all the views have been 
     registered (because they expect ALL the views to be 
     registered in order to compute the projection's hash
     and deduce the version number) *)
  mutable hash : string option ;
  mutable id : int option ;
  mutable version : int option ; 
  mutable prefix : Names.prefix option ; 

  (* Whenever a stream is tracked, it adds a generic sequence
     to this list. Reading an element from this sequence will 
     read an event from a sequence, run all event handlers,
     and return the clock of the event (for checkpointing). *)
  mutable streams : (Clock.t -> (ctx, ctx Run.effect * Clock.t) Seq.t) list ;  

  (* This service is responsible for running the projection functions. 
     It is woken up when the program starts and when an event is appended
     to a tracked stream. *)
  service : Run.service ;
}  

(* We're being sneaky : a view IS a projection. The different types
   are merely a way to force consumers to call [view] before
   [prefix], so that all prefixed views are registered. *)
type view = t 

(* Hashes the contents of the view. Once this is done, no more 
   views may be registered. *)
let hash t = 
  match t.hash with Some h -> h | None -> 
    let blob = String.concat ";" 
      (List.map (fun (n,v) -> n ^ "@" ^ string_of_int v) 
	 (List.sort compare t.contents)) in
    let h = Sha1.to_hex (Sha1.string blob) in
    t.hash <- Some h ; h 

(* Helper function for computing the identifier and version of a projection
   (done in a single function because both values are raead from the database
   in a single query)

   This function updates the projection fields. Once this is done, no more views
   may be registered. *)
let get_id_and_version t = 

  let! _ = return () in (* Wait until the return value is evaluated to start the loop. *)

  Run.loop begin fun continue -> 
    
    let hash = hash t in 
    
    let! r = Sql.query 
      ("SELECT \"id\", \"version\" FROM \"meta:projections\" WHERE \"name\" = $1 AND \"hash\" = $2")
      [ `String t.name ; `String hash ] in
    
    if Array.length r = 0 then 
      
      let! () = Sql.command begin
	"INSERT INTO \"meta:projections\" (\"name\", \"hash\", \"version\", \"clock\")"
	^ "SELECT CAST($1 as varchar), $2, 1 + COALESCE(MAX(\"version\"),0), $3 FROM \"meta:projections\" "
	^ "WHERE \"name\" = $1"
      end [ `String t.name ; `String hash ; `Binary (Pack.to_string Clock.pack Clock.empty) ] in
      
      continue
	
    else
      
      let id = int_of_string r.(0).(0) and version = int_of_string r.(0).(1) in
      t.id <- Some id ;
      t.version <- Some version ; 
      Run.return (id, version) 	
	
  end
    
(* The (numeric) identifier of a projection. Once computed, no more views may be 
   registered. *)
let id t = 
  match t.id with Some id -> Run.return id | None -> 
    let! id, _ = get_id_and_version t in 
    Run.return id

(* The version number of a projection. Once computed, no more views may be
   registered. *)
let version t = 
  match t.version with Some version -> Run.return version | None ->
    let! _, version = get_id_and_version t in 
    Run.return version 
      
(* The prefix of a projection. Once computed, no more views may be registered.
   However, this function does not compute the prefix, it merely returns a 
   task that computes it. *)
let prefix t = 
  match t.prefix with Some p -> p | None -> 
    let v = version t in
    let p = Names.projection_prefix t.name v in
    t.prefix <- Some p ; p

(* Register a new view. *)
let view t name version = 

  if t.hash <> None then 
    failwith (!! "Cannot register %s, projection %s is already compiled" name t.name) ;
    
  t.contents <- (name,version) :: t.contents ;
  
  ( t : view ) (* Sneaky *)

(* The current clock of a projection. This function computes the id, and so 
   prevents more views from being registered. *)
let clock t = 
  let! id = id t in 
  let! result = Sql.query ("SELECT \"clock\" FROM \"meta:projections\" WHERE \"id\" = $1") [ `Int id ] in
  Run.return (Pack.of_string Clock.unpack (Postgresql.unescape_bytea result.(0).(0)))

(* Save the clock. This is exclusively called internally to save checkpoints. *)
let save_clock t clock = 
  let! id = id t in 
  let () = if trace_events then Log.trace "[%s] checkpoint  : %s" (t.name) (Clock.to_json_string clock) in
  Sql.command ("UPDATE \"meta:projections\" SET \"clock\" = $1 WHERE \"id\" = $2")
    [ `Binary (Pack.to_string Clock.pack clock) ; `Int id ]

(* Runs a projection. Returns when out of events to process. *)
let run t = 

  Sql.using t.config (fun cqrs -> new cqrs_ctx cqrs) begin  
    
    let! c       = clock t in 	  
    let  actions = Seq.join (List.map (fun f -> f c) t.streams) in
    
    Run.loop begin fun continue -> 
      
      (* Expect at least one, so that we will wait for a new item if there
	 are none available. *)
      let! ready_actions = Seq.to_list ~min:1 100 actions in      
      if ready_actions = [] then 

	return () (* Out of items ! *)
      
      else 

	let start = Unix.gettimeofday () in
	
	let! () = Sql.transaction begin 

	  let! c = clock t in 	  
	  
	  let! c = List.M.fold_left begin fun clock (action,time) -> 
	    if Clock.earlier_than_checkpoint time clock then Run.return clock else
	      let! () = action in Run.return (Clock.merge time clock)
	  end c ready_actions in 	  
	  
	  save_clock t c
	    
	end in 

	let () = if trace_events then Log.trace "[%s] proc %.3fs : %d events " 
	    t.name (Unix.gettimeofday () -. start) (List.length ready_actions) in
	
	continue
	  
    end
 
  end

(* Creates a projection. Its service will be pinged by the 'run()' function below, 
   as well as by tracked streams. *)
let make name config = 

  let self = ref None in 
  
  let service = Run.service ("proj:" ^ name)
    (Run.of_call (fun () -> match !self with None -> assert false | Some t -> run t) ()) in

  let t = {
    name ;
    config ;
    contents = [] ; 
    hash = None ;
    id = None ;
    version = None ;
    prefix = None ;
    streams = [] ;
    service ; 
  } in

  self := Some t ; 
  
  projection_run_functions := (fun () -> Run.ping service) :: !projection_run_functions ;  
  t

(* Projection methods: stream side 
   =============================== *)

let of_view t = t

let name t = t.name

let register t stream = 
  t.streams <- stream :: t.streams ;
  t.service

(* Running all projections 
   ======================= *)

let run () = 

  let restart task exn = 
    Log.error "While running projection: %s" (Printexc.to_string exn) ;
    task ()
  in

  List.fold_left 
    (fun acc task -> Run.fork (restart task) (task ()) acc) 
    (Run.return ()) !projection_run_functions

(* Waiting on a projection 
   ======================= *)

exception LeftBehind of string * Clock.t * Clock.t

(* This code does not perform any low-level work: it simply polls
   'clock' until it either times out or the condition is satisfied. *)
let wait_until_after t after = 

  (* On failure, waits 100 * 2^{2 * number of tries} milliseconds: 
       50 ; 100 ; 400 ; 1600 ; 25600 ; raise LeftBehind
     Max waiting time = 27.75s *)
  let rec retry attempts = 
     (* TODO: attempt with a cached version first. *)
     let! current = clock t in 
     if Clock.earlier_than_constraint after current then return attempts else
       if attempts = 5 then raise (LeftBehind (t.name, current, after)) else
         let! () = Run.sleep (float_of_int (1 lsl (2 * attempts)) *. 50.) in
         retry (attempts + 1)
  in
  
  let  start = Unix.gettimeofday () in
  let! attempts = retry 0 in
  let () = if trace_events && attempts > 0 then Log.trace "[%s] wait %.3fs : %s" 
      t.name (Unix.gettimeofday () -. start) (Json.serialize (Clock.to_json after)) in
  return () 

let wait ?clock t = 

  let! clock = 
    match clock with Some clock -> return clock | None -> 
      let! ctx = Run.context in 
      return (ctx # after) 
  in

  if Clock.is_empty clock then return () else wait_until_after t clock 

(* Meta tables
   =========== *)

let () = 
  
  Sql.on_first_connection (Sql.command begin 
    "CREATE TABLE IF NOT EXISTS \"meta:projections\" ( " 
    ^ "\"id\" SERIAL, "
    ^ "\"name\" VARCHAR(64), "
    ^ "\"hash\" CHAR(40), "
    ^ "\"version\" INTEGER, "
    ^ "\"clock\" BYTEA, "
    ^ "PRIMARY KEY (\"id\"), "
    ^ "UNIQUE (\"name\",\"version\") "
    ^ ");" 
  end [])
