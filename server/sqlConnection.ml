(* © 2014 RunOrg *)

open Std

(* A 't' connection keeps a queue of operations to be performed, and runs
   them against a 'pgsql' connection which is created on-the-fly. Pooling 
   is applied to 'pgsql' connections. 

   All the work is done in the [process] function below, which forwards 
   appropriate calls to members of type [operation]. Exceptions raised in 
   [process] are treated as fatal errors and will shut down the process. 
*)

(* Connection pooling
   ================== *)

type config = {
  host : string ;
  port : int ;
  database : string ;
  user : string ;
  password : string ;
  pool_size : int ;
}

(* Forcibly disconnects from a postgreSQL database. Obviously not
   returning it to the pool. *)
let disconnect pgsql = 
  pgsql # finish 

exception ConnectionFailed of string

(* Connect to the database. Does not use the pool. *)
let connect config = 
  try 
    let sql = new Postgresql.connection 
      ~host:config.host
      ~port:(string_of_int config.port)
      ~dbname:config.database
      ~user:config.user 
      ~password:config.password
      () in
    sql # set_nonblocking true ; 
    sql 
  with 
  | Postgresql.Error (Postgresql.Connection_failure message) -> raise (ConnectionFailed message)
  | Postgresql.Error reason -> raise (ConnectionFailed (Postgresql.string_of_error reason)) 

(* A pool of connections. There is one such pool for every
   configuration object. *)
type pool = {
  mutable pool : Postgresql.connection list ;
  mutable size : int ;
  max_size : int ; 
}
 
(* Connection pools, keyed by (host,port,db) *)
let pools = Hashtbl.create 10 

(* Returns the pool for the provided configuration, and whether 
   this is the first time this pool is requested. *)
let get_pool config = 
  let key = (config.host, config.port, config.database) in 
  try false, Hashtbl.find pools key with Not_found ->
    let pool = { pool = [] ; size = 0 ; max_size = config.pool_size } in
    Hashtbl.add pools key pool ;
    true, pool 

(* Connect to the database. Picks a connection out of the pool, 
   if there is one. *)
let connect_from_pool config = 
  let _, pool = get_pool config in 
  match pool.pool with 
  | []     -> connect config
  | h :: t -> pool.pool <- t ; pool.size <- pool.size - 1 ; h

(* Returns a connection to the pool. If the pool is full, kills the connection. *)
let return_to_pool config = function 
  | None -> () 
  | Some pgsql -> let _, pool = get_pool config in 
		  if pool.size = pool.max_size then disconnect pgsql else
		    ( pool.size <- pool.size + 1 ; pool.pool <- pgsql :: pool.pool ) 

(* Data types 
   ========== *)

type query = string

type param = 
  [ `Binary of string 
  | `String of string 
  | `Id of Id.t
  | `Int of int ] 

type result = string array array 

(* An operation that needs to be performed by this query. *)
type operation = {

  (* Run this function to start the operation. *)
  start : Postgresql.connection -> unit ;

  (* Run this function to determine if the operation is finished. 
     If [`Failed], may call [start] on another connection. *)
  poll : Postgresql.connection -> [ `Finished | `Waiting | `Failed of exn ] ;

  (* This function loops until a result is available, calling its
     first parameter on each iteration then yielding if no result
     was found. *)
  wait : 'ctx. (unit -> unit) -> ('ctx, result) Run.t ;

  (* Transaction-related meta-information. Helps mark the connection as 
     'in transaction' when applicable. *)
  special : [ `BeginTransaction | `EndTransaction ] option ; 

  (* The query that generated this operation. For debugging and logging purporses. *)
  query : query ; 

}

(* A raw database connection. *)
type t = {

  (* The database connection, if any. A brand new database connection will
     be created the first time it is required. *)
  mutable pgsql : Postgresql.connection option ;

  (* The operation being executed by the database right now. *)
  mutable current : operation option ; 

  (* Operations that will start once the current operation finishes. *)
  pending : operation Queue.t ;

  (* The configuration used to connect to the database. *)
  config : config ;

  (* Is this the first time a database connection was requested for this
     configuration ? *)
  first : bool ; 

  (* Is this connection running a transaction ? If a query fails during a 
     transaction, there are no retries. *)
  mutable transaction : bool ; 

  (* Has this connection been marked for relase ? This would make executing
     anything a fatal error. *)
  mutable released : bool ; 
}

(* Operations 
   ========== *)

exception OperationFailed of exn 

let operation ?special (query:string) params = 

  (* The number of times this operation has failed. *)
  let fail_count = ref 0 in 

  (* Result is stored in this reference. *)
  let result : (result, exn) Std.result option ref = ref None in

  (* Starts the query on a new database. *)
  let start (pgsql:Postgresql.connection) =

    result := None ;

    let binary_params = Array.of_list (List.map (function
      | `Binary _ -> true
      | `String _ 
      | `Id _ 
      | `Int _ -> false
    ) params) in 
    
    let params = Array.of_list (List.map (function 
      | `Binary s 
      | `String s -> s
      | `Id     i -> Id.to_string i
      | `Int    i -> string_of_int i  
    ) params) in
    
    try 
      pgsql # send_query ~params ~binary_params query ;
      pgsql # flush 
    with exn -> 
      result := Some (Bad exn)

  in

  (* Polls a database for a query result. *)
  let poll pgsql = 
    
    if !result = None then begin 

      try 
	pgsql # consume_input ;
	match pgsql # get_result with None -> () | Some r -> 
	  if not (pgsql # is_busy) then 
	    result := Some (Ok (r # get_all)) 	  
      with exn -> 
	result := Some (Bad exn) 

    end ;

    match !result with 
      | None           -> `Waiting
      | Some (Ok _)    -> `Finished 
      | Some (Bad exn) -> 
	
	incr fail_count ; 
	result := None ; 
	if !fail_count > 1 then begin
	  raise (OperationFailed exn)
	end else
	  `Failed exn

  in

  (* Stay busy waiting for a result. *)
  let rec wait process = 
    process () ;
    match !result with 
    | Some (Ok r)  -> return r
    | Some (Bad _) (* <-- let 'poll' handle this *)
    | None         -> Run.yield (Run.of_call wait process) 
  in
    
  { start ; poll ; wait ; special ; query }

(* Running queries 
   =============== *)

exception FailedDuringTransaction of exn
exception ConnectionReleased of string 

(* Does a step of processing on the SQL database. Call this
   function on before checking for any results. *)
let rec process t = 

  (* Select the next operation 'op' to be performed. *)
  match t.current with 
  | None when Queue.is_empty t.pending -> () (* Nothing to do... *)
  | None -> let op = Queue.take t.pending in 
	    ( match t.pgsql with Some pgsql -> op.start pgsql | None -> () ) ;
	    t.current <- Some op ;
	    process t 
  | Some op -> 

    if t.released then 
      raise (ConnectionReleased op.query) ;

    if op.special = Some `BeginTransaction then
      t.transaction <- true ;

    if op.special = Some `EndTransaction then 
      t.transaction <- false ; 

    (* Select the database 'pgsql' on which the next operation *HAS* 
       already been started. *)
    match t.pgsql with 
    | None -> let pgsql = connect_from_pool t.config in 
	      op.start pgsql ;
	      t.pgsql <- Some pgsql ;
	      process t 
    | Some pgsql -> 

      (* Poll and process the result. *)
      match op.poll pgsql with 
      | `Waiting    -> () 
      | `Finished   -> t.current <- None ; process t 
      | `Failed exn -> 
	
	if t.transaction then 
	  raise (FailedDuringTransaction exn)
	else begin
	  disconnect pgsql ;
	  t.pgsql <- None ;
	  process t  
	end

(* Wrapper around [process] above. Catches any exceptions and treats them as 
   critical failures. *)
let process t = 
  try process t with 
  | FailedDuringTransaction (OperationFailed exn) 
  | FailedDuringTransaction exn ->  
    
    Log.error "[FATAL] SQL error during transaction: %s" (Printexc.to_string exn) ;
    exit (-1) 
      
  | ConnectionFailed reason -> 
    
    Log.error "[FATAL] SQL connection failed: %s" reason ; 
    exit (-1) 
      
  | OperationFailed exn -> 
    
    Log.error "[FATAL] SQL error not solved by re-connection: %s" (Printexc.to_string exn) ;
    exit (-1) 

  | ConnectionReleased query -> 

    Log.error "[FATAL] SQL connection released while executing:\n%s" query ;
    exit (-1) ; 
      
  | exn ->
    
    Log.error "[FATAL] Unknown SQL error: %s" (Printexc.to_string exn) ;
    exit (-1) 
    
(* Start executing a query *)
let run t ?special query params = 
  let operation = operation ?special query params in   
  Queue.push operation t.pending ;
  operation.wait (fun () -> process t) 

(* Public functions 
   ================ *)

(* Connect to the database. *)
let connect config = {
  pgsql       = None ; 
  current     = None ;
  config      ;
  first       = fst (get_pool config) ;
  pending     = Queue.create () ;
  transaction = false ; 
  released    = false ; 
}
    
(* Is this the first connection to this database by this process ? *)
let is_first_connection t = 
  t.first 

(* Public function for executing a query. *)
let execute t query params = 
  run t query params 
  
(* Start a transaction. *)
let transaction t = 
  let! _ = run t ~special:`BeginTransaction "BEGIN TRANSACTION" [] in
  return ()

(* End a transaction.*)
let commit t = 
  let! _ = run t ~special:`EndTransaction "COMMIT" [] in
  return () 

(* Release a transaction. *)
let release t =

  let do_release () = 
    return_to_pool t.config t.pgsql ;
    t.released <- true ;
    return () 
  in
 
  if t.current = None && Queue.is_empty t.pending then do_release () else
    let! () = Run.sleep 30000.0 in
    do_release () 
