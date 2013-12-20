type operation = {
  start : Postgresql.connection -> unit ;
  finish : Postgresql.connection -> bool ;
  query : string ; 
}

type param = 
  [ `Binary of string 
  | `String of string 
  | `Int of int ] 

type result = string array array 

type cqrs = {
  pgsql : Postgresql.connection ;
  pending : operation Queue.t ;
  mutable current : operation option ; 
  mutable first : bool ; 
}

(* Connecting to the database 
   ========================== *)

type config = {
  host : string ;
  port : int ;
  database : string ;
  user : string ;
  password : string 
}

exception ConnectionFailed of string

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
  | Postgresql.Error reason -> failwith (Postgresql.string_of_error reason) 

(* First connection queries 
   ======================== *)

let already_connected = Hashtbl.create 10 

let is_first_connection config = 
  let key = (config.host, config.port, config.database) in 
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
  
class type ctx = object ('self)
  method cqrs : cqrs
  method time : Time.t 
  method with_time : Time.t -> 'self
  method db : Id.t
  method with_db : Id.t -> 'self
end 

class cqrs_ctx config = object (self)

  val cqrs = make_cqrs config

  method cqrs = 
    if cqrs.first then begin
      cqrs.first <- false ;
      Run.eval (self :> ctx) !on_first_connection
    end ;
    cqrs

  val time = Time.now () 

  method time = time
  method with_time time = {< time = time >}
      
  val db = Id.of_string "00000000000"

  method db = db
  method with_db db = {< db = db >}

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
