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
  connect : unit -> ctx ; 

  (* A list of all views (kind, name and version number) that
     were registered in this projection. *)
  mutable contents : (string * string * int) list ;

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
      (List.map (fun (k,n,v) -> k ^ ":" ^ n ^ "@" ^ string_of_int v) 
	 (List.sort compare t.contents)) in
    let h = Sha1.to_hex (Sha1.string blob) in
   t. hash <- Some h ; h 

(* Helper function for computing the identifier and version of a projection
   (done in a single function because both values are raead from the database
   in a single query)

   This function updates the projection fields. Once this is done, no more views
   may be registered. *)
let get_id_and_version t = 

  Run.loop begin fun continue -> 
    
    let hash = hash t in 
    
    let! r = query 
      ("SELECT \"id\", \"version\" FROM \"meta:projections\" WHERE \"name\" = $1 AND \"hash\" = $2")
      [ `String t.name ; `String hash ] in
    
    if Array.length r = 0 then 
      
      let! () = command begin
	"INSERT INTO \"meta:projections\" (\"name\", \"hash\", \"version\", \"clock\")"
	^ "SELECT $1, $2, 1 + COALESCE(MAX(\"version\"),0), $3 FROM \"meta:projections\" "
	^ "WHERE \"name\" = $1 AND \"hash\" = $2"
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
let view t kind name version = 

  if t.hash <> None then 
    failwith (!! "Cannot register %s, projection %s is already compiled" name t.name) ;
    
  t.contents <- (kind,name,version) :: t.contents ;
  
  ( t : view ) (* Sneaky *)

(* The current clock of a projection. This function computes the id, and so 
   prevents more views from being registered. *)
let clock t = 
  let! id = id t in 
  let! result = query ("SELECT \"clock\" FROM \"meta:projections\" WHERE \"id\" = $1") [ `Int id ] in
  Run.return (Pack.of_string Clock.unpack (Postgresql.unescape_bytea result.(0).(0)))

(* Save the clock. This is exclusively called internally to save checkpoints. *)
let save_clock t clock = 
  let! id = id t in 
  command ("UPDATE \"meta:projections\" SET \"clock\" = $1 WHERE \"id\" = $2")
    [ `Binary (Pack.to_string Clock.pack clock) ; `Int id ]

(* Runs a projection. Forever. *)
let run t = 

  Run.with_context (t.connect ()) begin  
    
    let! c       = clock t in 	  
    let  actions = Seq.join (List.map (fun f -> f c) t.streams) in
    
    Run.loop begin fun continue -> 
      
      let! ready_actions = Seq.to_list ~min:0 100 actions in      
      if ready_actions = [] then 

	let! () = Run.sleep 1.0 in
	continue
      
      else 
	
	let! () = transaction begin 
	  
	  let! c = clock t in 	  
	  
	  let! c = List.M.fold_left begin fun clock (action,time) -> 
	    if Clock.earlier_than_checkpoint time clock then Run.return clock else
	      let! () = action in Run.return (Clock.merge time clock)
	  end c ready_actions in 	  
	  
	  save_clock t c
	    
	end in 
	
	continue
	  
    end
 
  end
  
(* Creates a projection. Registers it for being run with all the
   others. *)
let make name connect = 

  let t = {
    name ;
    connect ;
    contents = [] ; 
    hash = None ;
    id = None ;
    version = None ;
    prefix = None ;
    streams = [] ;
  } in
  
  projection_run_functions := (fun () -> run t) :: !projection_run_functions ;
  t

(* Projection methods: stream side 
   =============================== *)

let of_view t = t

let name t = t.name

let register t stream = 
  t.streams <- stream :: t.streams

(* Running all projections 
   ======================= *)

let run () = 
  List.fold_left (fun acc task -> Run.fork (task ()) acc) (Run.return ()) !projection_run_functions

(* Meta tables
   =========== *)

let () = 
  
  query_on_first_connection begin 
    "CREATE TABLE IF NOT EXISTS \"meta:projections\" ( " 
    ^ "\"id\" SERIAL, "
    ^ "\"name\" VARCHAR(64), "
    ^ "\"hash\" CHAR(40), "
    ^ "\"version\" INTEGER, "
    ^ "\"clock\" BYTEA, "
    ^ "PRIMARY KEY (\"id\"), "
    ^ "UNIQUE (\"name\",\"version\") "
    ^ ");" 
  end []
