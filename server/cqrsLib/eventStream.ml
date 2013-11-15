(* © 2013 RunOrg *)

open Common
open Std

type ('ctx, 'a) event_writer = 'a list -> ( 'ctx, unit ) Run.t

type 'a event_wrapper = <
  clock : Clock.t ;
  event : 'a ;
  time  : Time.t ; 
>

type ('ctx, 'a) stream = Clock.t -> ( 'ctx, 'a event_wrapper ) Seq.t 

module type STREAM = sig
  type event
  val name : string
  val append : ( #ctx, event ) event_writer
  val count : unit -> ( #ctx, int ) Run.t
  val clock : unit -> ( #ctx, Clock.t ) Run.t
  val track : Projection.view -> (event -> ctx Run.effect) -> unit
end

module Stream = functor(Event:sig 
  include Fmt.FMT
  val name : string 
end) -> struct

  type event = Event.t
  let name = Event.name 
  let dbname = Names.stream name

  module Data = type module ( Time.t * Event.t )  

  class wrapper id n time event = object

    val clock = Clock.at id n 
    method clock = clock 

    val event : event = event 
    method event = event 

    val time : Time.t = time
    method time = time

  end

  let () = 
    
    Sql.query_on_first_connection begin 
      "CREATE TABLE IF NOT EXISTS \"" ^ dbname ^ "\" ( " 
      ^ "\"n\" SERIAL, "
      ^ "\"event\" BYTEA, "
      ^ "PRIMARY KEY (\"n\") "
      ^ ");" 
    end []

  (* Appending events to the stream 
     ============================== *)

  let append events = 
    
    let! ctx = Run.context in     
    let  time = ctx # time in    
    let  packs = List.map (fun event -> `Binary (Pack.to_string Data.pack (time, event))) events in

    if packs = [] then Run.return () else 

      Sql.safe_command begin 
	"INSERT INTO \"" ^ dbname ^ "\" ( \"event\" ) VALUES " ^ 
	  (String.concat ", " (BatList.mapi (fun i _ -> "($" ^ string_of_int (i+1) ^ ")") packs))
      end packs 

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
	  let! () = Sql.safe_command ("INSERT INTO \"meta:streams\" (\"name\") VALUES ($1)") [ `String name ] in 
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
      ("SELECT \"n\", \"event\" from \"" ^ dbname ^ "\" WHERE \"n\" >= $1 "
	  ^ "ORDER BY \"n\" LIMIT " ^ string_of_int count) 
      [ `Int start ] in

    let next = 
      if Array.length result = 0 then start else 
	1 + int_of_string result.(Array.length result - 1).(0) in

    let list = List.map (fun line -> 
      let n = int_of_string line.(0) in
      let time, event = Pack.of_string Data.unpack (Postgresql.unescape_bytea line.(1)) in 
      new wrapper id n time event) (Array.to_list result) in

    Run.return (list, next) 

  let start_revision clock = 
    let! id = id () in 
    Run.return (match Clock.get clock id with None -> 0 | Some n -> n + 1)

  let follow clock = 
    Seq.of_infinite_cursor begin fun start_opt -> 
      
      let! start = match start_opt with 
	| Some start -> Run.return start 
	| None       -> start_revision clock in 
      
      read_batch start 100

    end None 

  (* Tracking events within a projection 
     =================================== *)

  let trackers = Hashtbl.create 10

  let track view action = 

    let name = Projection.name (Projection.of_view view) in

    let stream clock =
      (* No need to try for exceptions: we will add a value to the
	 hash table before this function is called. *)
      let actions = Hashtbl.find trackers name in
      Seq.map begin fun wrap -> 
	let ev = wrap # event and clock = wrap # clock in 
	(* TODO: set context time to wrap # time *)
	List.M.iter (fun action -> action ev) actions, clock 
      end (follow clock)
    in

    let actions = 
      try Hashtbl.find trackers name with Not_found -> 
	Projection.register view stream ; []
    in

    Hashtbl.add trackers name (action :: actions)

end

let () = 
  
  Sql.query_on_first_connection begin 
    "CREATE TABLE IF NOT EXISTS \"meta:streams\" ( " 
    ^ "\"id\" SERIAL, "
    ^ "\"name\" VARCHAR(64), "
    ^ "PRIMARY KEY (\"id\"), "
    ^ "UNIQUE (\"name\") "
    ^ ");" 
  end []
