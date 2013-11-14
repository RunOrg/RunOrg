type operation = {
  start : Postgresql.connection -> unit ;
  finish : Postgresql.connection -> bool ;
  query : string ; 
}

type cqrs = {
  pgsql : Postgresql.connection ;
  pending : operation Queue.t ;
  mutable current : operation option ; 
  mutable first : bool ; 
}

type param = [ `Binary of string 
	     | `String of string 
	     | `Int of int ] 

type result = string array array 

(* Connecting to the database 
   ========================== *)

type config = {
  cfg_host : string ;
  cfg_port : int ;
  cfg_database : string ;
  cfg_user : string ;
  cfg_password : string 
}

exception ConnectionFailed of string

let connect config = 
  try 
    let sql = new Postgresql.connection 
      ~host:config.cfg_host
      ~port:(string_of_int config.cfg_port)
      ~dbname:config.cfg_database
      ~user:config.cfg_user 
      ~password:config.cfg_password
      () in
    sql # set_nonblocking true ; 
    sql 
  with 
  | Postgresql.Error (Postgresql.Connection_failure message) -> raise (ConnectionFailed message)
  | Postgresql.Error reason -> failwith (Postgresql.string_of_error reason) 

(* First connection queries 
   ======================== *)

let already_connected = Hashtbl.create 10 

let is_first_connection config = 
  let key = (config.cfg_host, config.cfg_port, config.cfg_database) in 
  if Hashtbl.mem already_connected key then false else
    (Hashtbl.add already_connected key () ; true)

let on_first_connection = ref (Run.return ())

(* Creating connections 
   ==================== *)

let make_cqrs config = { 
  pgsql = connect config ; 
  pending = Queue.create () ; 
  current = None ;
  first = is_first_connection config ; 
} 
  
class type ctx = object
  method cqrs : cqrs
  method time : Time.t 
end 

class virtual cqrs_ctx config = object (self)

  val cqrs = make_cqrs config

  method cqrs = 
    if cqrs.first then begin
      cqrs.first <- false ;
      Run.eval (self :> ctx) !on_first_connection
    end ;
    cqrs

  method virtual time : Time.t
      
end

(* Running queries 
   =============== *)
  
let start query params (sql:Postgresql.connection) = 
  
  let binary_params = Array.of_list (List.map (function
    | `Binary _ -> true
    | `String _ 
    | `Int _ -> false
  ) params) in 

  let params = Array.of_list (List.map (function 
    | `Binary s 
    | `String s -> s
    | `Int    i -> string_of_int i  
  ) params) in

  Log.trace "%s%s" query  
    (if Array.length params = 0 then "" else 
	"[" ^ (String.concat ", " (List.map (Printf.sprintf "%S") (Array.to_list params))) ^ "]") ;

  sql # send_query ~params ~binary_params query ;
  sql # flush 

let rec start_next_query cqrs = 
  if not (Queue.is_empty cqrs.pending) then
    let op = Queue.take cqrs.pending in
    try 
      op.start cqrs.pgsql ; 
      cqrs.current <- Some op 
    with Postgresql.Error reason -> 
      failwith (Postgresql.string_of_error reason ^ "[ON START] " ^ op.query) 
 
let poll_current_query cqrs = 
  match cqrs.current with None -> () | Some op ->
    try 
      if op.finish cqrs.pgsql then cqrs.current <- None 
    with Postgresql.Error reason -> 
      failwith (Postgresql.string_of_error reason ^ "[ON FINISH] " ^ op.query) 

let rec process cqrs = 
  poll_current_query cqrs ; 
  if cqrs.current = None then start_next_query cqrs 

let dump result = 
  Log.trace "RESULT: %s" (Postgresql.result_status (result # status)) ;
  Array.iter (fun line ->
    Log.trace "%s" ("[" ^ (String.concat ", " (List.map (Printf.sprintf "%S") (Array.to_list line))) ^ "]") ;
  ) (result # get_all) 

let make_result_waiter query = 
  let result = ref None in 
  let finish pgsql = 
    try 
      pgsql # consume_input ; 
      match pgsql # get_result with 
      | None -> false
      | Some r ->  	
	dump r ; 
	if pgsql # is_busy then false else ( result := Some (r # get_all) ; true )
    with Postgresql.Error reason -> 
      failwith (Postgresql.string_of_error reason) 
  in
  let rec wait cqrs =    
    process cqrs ;
    match !result with 
    | None -> Run.(yield (of_call wait cqrs))
    | Some r -> Run.return r
  in 
  finish, wait 

let query query params = 

  let! ctx = Run.context in 
  let  cqrs = ctx # cqrs in 

  let start = start query params in 
  let finish, wait = make_result_waiter query in 
  Queue.add { query ; start ; finish } cqrs.pending ; 
  wait cqrs

let command q p = let! _ = query q p in Run.return () 

(* Registering for first connection. 
   ================================= *)

let run_on_first_connection what =
  let current = !on_first_connection in 
  on_first_connection := (let! () = current in what)

let query_on_first_connection query params =
  run_on_first_connection (command query params)

(* Transactions 
   ============ *)

let mutex = new Run.mutex

let safe_command q p = 
  mutex # if_unlocked (command q p)

let transaction action = 
  mutex # lock begin 
    let! () = command "BEGIN TRANSACTION" [] in
    let! result = action in 
    let! () = command "COMMIT" [] in
    Run.return result
  end 
