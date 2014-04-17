(* © 2014 RunOrg *)

open Common
open Std

type ('ctx, 'a) event_writer = 'a list -> ( 'ctx, Clock.t ) Run.t

module type STREAM = sig
  type event
  val name : string
  val append : ( #ctx, event ) event_writer
  val count : unit -> ( #ctx, int ) Run.t
  val clock : unit -> ( #ctx, Clock.t ) Run.t
  val track : Projection.view -> (event -> ctx Run.effect) -> unit
  val track_full : Projection.view -> (< clock : Clock.t ; event : event > -> ctx Run.effect) -> unit
end

module Stream = functor(Event:sig 
  include Fmt.FMT
  val name : string 
end) -> struct

  type event = Event.t
  let name = Event.name 
  let dbname = Names.stream name

  module Data = type module ( Time.t * Event.t )  

  class wrapper id db n time event = object

    val clock = Clock.at id n 
    method clock = clock 

    val event : event = event 
    method event = event 

    val time : Time.t = time
    method time = time

    val db : Id.t = db
    method db = db 

  end

  let () = 
    
    Sql.on_first_connection (Sql.command begin 
      "CREATE TABLE IF NOT EXISTS \"" ^ dbname ^ "\" ( " 
      ^ "\"n\" SERIAL, "
      ^ "\"db\" CHAR(11), "
      ^ "\"event\" BYTEA, "
      ^ "PRIMARY KEY (\"n\") "
      ^ ");" 
    end [])

  (* Counting events 
     =============== *)

  let count () = 
    
    let! result = Sql.query ("SELECT COUNT(*) FROM \"" ^ dbname ^ "\"") [] in
    Run.return (int_of_string (result.(0).(0))) 
     
  (* Identifier management 
     ===================== *)

  let id_cache : (ctx, int) Run.t = 
    Run.memo begin 
      let rec recurse () = 
	let! result = Sql.query ("SELECT \"id\" FROM \"meta:streams\" WHERE \"name\" = $1") [ `String name ] in
	if Array.length result < 1 then 
	  let! _ = Sql.safe_query ("INSERT INTO \"meta:streams\" (\"name\") VALUES ($1)") [ `String name ] in 
	  recurse () 
	else
	  Run.return (int_of_string result.(0).(0))
      in
      recurse () 
    end

  let id () = 

    (* TODO: id should depend on database. *)
    Run.edit_context (fun ctx -> (ctx :> ctx)) id_cache

  (* Clock management 
     =============== *)

  let clock () = 
    
    let! result = Sql.query ("SELECT MAX(\"n\") FROM \"" ^ dbname ^ "\"") [] in
    let! id = id () in
    Run.return (Clock.at id (int_of_string (result.(0).(0)))) 

  (* Reading events 
     ============== *)

  let read_batch start count = 

    let! id = id () in 
    let! result = Sql.query 
      ("SELECT \"n\", \"db\", \"event\" from \"" ^ dbname ^ "\" WHERE \"n\" >= $1 "
	  ^ "ORDER BY \"n\" LIMIT " ^ string_of_int count) 
      [ `Int start ] in

    let next = 
      if Array.length result = 0 then None else 
	Some (1 + int_of_string result.(Array.length result - 1).(0)) in

    let list = List.map begin fun line -> 
      let n = int_of_string line.(0) in
      let db = Id.of_string line.(1) in
      try 
	let time, event = Pack.of_string Data.unpack (Postgresql.unescape_bytea line.(2)) in 
	new wrapper id db n time event	    
      with exn -> 
	Log.exn exn (!! "When unpacking event %s:%d" Event.name n) ;
	raise exn 
    end (Array.to_list result) in

    Run.return (list, next) 

  let start_revision clock = 
    let! id = id () in 
    Run.return (match Clock.get clock id with None -> 0 | Some n -> n + 1)
     
  let read_all_since clock = 

    Seq.of_finite_cursor begin fun start_opt -> 
      
      let! start = match start_opt with 
	| Some start -> Run.return start 
	| None       -> start_revision clock in 
      
      read_batch start 100

    end None 

  (* Tracking events within a projection 
     =================================== *)

  let trackers = Hashtbl.create 10
  let track_services = ref []

  let track_full view action = 

    let name = Projection.name (Projection.of_view view) in

    let process_all_since clock =
      (* No need to try for exceptions: we will add a value to the
	 hash table before this function is called. *)
      let actions = Hashtbl.find trackers name in
      (* Reverse actions (they should be executed in the order they were 
	 defined in) *)
      let actions = List.rev actions in 
      Seq.map begin fun wrap -> 

	let ev = wrap # event and clock = wrap # clock and db = wrap # db and time = wrap # time in 

	let arg = object
	  val event = ev
	  method event = event
	  val clock = clock
	  method clock = clock
	end in

	(Run.edit_context (fun ctx -> (ctx # with_time time) # with_db db)
	   (List.M.iter_seq (fun action -> action arg) actions)), clock

      end (read_all_since clock)
    in

    let actions = 
      try Hashtbl.find trackers name with Not_found -> 
	let service = Projection.register view process_all_since in
	track_services := service :: !track_services ;
	[]
    in

    Hashtbl.add trackers name (action :: actions)

  let track view action = 
    track_full view (fun arg -> action (arg # event))

  (* Appending events to the stream 
     ============================== *)

  let append events = 
    
    let! ctx = Run.context in     
    let  time = ctx # time and db = ctx # db in 
    let  packs = List.map (fun event -> `Binary (Pack.to_string Data.pack (time, event))) events in

    if packs = [] then clock () else 

      let  prefix = Printf.sprintf "('%s',$" (Id.to_string db) in
      let! result = Sql.safe_query begin 
	"INSERT INTO \"" ^ dbname ^ "\" ( \"db\", \"event\" ) VALUES "
	^ (String.concat ", " (BatList.mapi (fun i _ -> prefix ^ string_of_int (i+1) ^ ")") packs))
	^ " RETURNING lastval()"
      end packs in

      let! id = id () in
      let  clock = Clock.at id (int_of_string (result.(0).(0))) in

      (* Wake up all projections that depend on this stream. *)
      let! () = List.M.iter Run.ping !track_services in 

      Run.return clock

end

let () = 
  
  Sql.on_first_connection (Sql.command begin 
    "CREATE TABLE IF NOT EXISTS \"meta:streams\" ( " 
    ^ "\"id\" SERIAL, "
    ^ "\"name\" VARCHAR(64), "
    ^ "PRIMARY KEY (\"id\"), "
    ^ "UNIQUE (\"name\") "
    ^ ");" 
  end [])
