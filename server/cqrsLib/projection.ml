open Std
open Common

let projection_run_functions = ref []

class ['ctx] projection mkctx name = object (self)
    
  val name : string = name 
  val mkctx : (#ctx as 'ctx) Lazy.t = mkctx

  (* Registered sub-elements and hash 
     ================================ *)

  val mutable contents = []
  val mutable hash = None

  method register kind name' version= 

      if hash <> None then 
	failwith (Printf.sprintf 
		    "Cannot register %s, projection %s is already compiled"
		    name name') ;

    contents <- (kind, name',version) :: contents ;
    
    self # prefix 

  method private hash = 
    match hash with Some h -> h | None -> 
      let blob = String.concat ";" 
	(List.map (fun (k,n,v) -> k ^ ":" ^ n ^ "@" ^ string_of_int v) 
	   (List.sort compare contents)) in
      let h = Sha1.to_hex (Sha1.string blob) in
      hash <- Some h ; h 

  (* Numeric projection identifier
     ============================= *)

  val mutable id = None
  val mutable version = None

  method private get_id_and_version : (ctx, int * int) Run.t = 

    Run.loop begin fun continue -> 

      let hash = self # hash in 

      let! r = query 
	("SELECT \"id\", \"version\" FROM \"meta:projections\" WHERE \"name\" = $1 AND \"hash\" = $2")
	[ `String name ; `String hash ] in

      if Array.length r = 0 then 

	let! () = command begin
	  "INSERT INTO \"meta:projections\" (\"name\", \"hash\", \"version\", \"clock\")"
	  ^ "SELECT $1, $2, 1 + COALESCE(MAX(\"version\"),0), $3 FROM \"meta:projections\" "
	  ^ "WHERE \"name\" = $1 AND \"hash\" = $2"
	end [ `String name ; `String hash ; `Binary (Pack.to_string Clock.pack Clock.empty) ] in

	continue

      else
	
	let id = int_of_string r.(0).(0) and version = int_of_string r.(0).(1) in
	Run.return (id, version) 

    end

  method private id : ('ctx, int) Run.t = 
    match id with Some id -> Run.return id | None -> 
      Run.edit_context (fun ctx -> (ctx :> ctx)) begin
	let! id', version' = self # get_id_and_version in 
	Run.return ( id <- Some id' ; version <- Some version' ; id' )
      end

  method private version : (ctx, int) Run.t = 
    match version with Some version -> Run.return version | None ->
      let! id', version' = self # get_id_and_version in 
      Run.return ( id <- Some id' ; version <- Some version' ; version' )

  (* Prefix construction 
     =================== *)

  val mutable prefix = None

  method private prefix = 
    match prefix with Some p -> p | None -> Names.projection_prefix name (self # version)  

  (* Clock management 
     ================ *)

  method clock = 
    let! id = self # id in 
    let! result = query ("SELECT \"clock\" FROM \"meta:projections\" WHERE \"id\" = $1") [ `Int id ] in
    Run.return (Pack.of_string Clock.unpack (Postgresql.unescape_bytea result.(0).(0)))

  method private save_clock clock = 
    let! id = self # id in 
    command ("UPDATE \"meta:projections\" SET \"clock\" = $1 WHERE \"id\" = $2")
      [ `Binary (Pack.to_string Clock.pack clock) ; `Int id ]

  (* Following streams
     ================= *)

  val mutable action_streams : (Clock.t -> ('ctx, 'ctx Run.effect * Clock.t) Seq.t) list = [] 

  method private run () = 
    
    Run.with_context (Lazy.force mkctx) begin  

      let! clock = self # clock in 	  
      let actions = Seq.join (List.map (fun f -> f clock) action_streams) in
      
      let rec loop () = 
	
	let! ready_actions = Seq.to_list ~min:0 100 actions in
	
	if ready_actions = [] then Run.yield (Run.of_call loop ()) else 
	  
	  let! () = transaction begin 
	    
	    let! clock = self # clock in 	  
	    
	    let! clock = List.M.fold_left begin fun clock (action,time) -> 
	      if Clock.earlier_than_checkpoint time clock then Run.return clock else
		let! () = action in Run.return (Clock.merge time clock)
	    end clock ready_actions in 	  
	    
	    self # save_clock clock  
	      
	  end in 
	  
	  loop () 
	    
      in
    
      loop ()

    end
				       
  (* Registering a stream
     ==================== *)

  val mutable registered = false

  method on : 'event. ('ctx, 'event) EventStream.stream -> ('event -> 'ctx Run.effect) -> unit =
    fun stream action ->

      if not registered then begin 
	projection_run_functions := (self # run) :: !projection_run_functions ;
	registered <- true 	  
      end ;

      let on_event ev = Run.of_call action (ev # event), ev # clock in
      let stream clock = Seq.map on_event (stream clock) in
 
      action_streams <- stream :: action_streams	     

end

(* Running all projections 
   ======================= *)

let run_projections () = 
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
