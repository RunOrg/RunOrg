(* © 2014 RunOrg *)

open Common

(* Connection pools
   ================ *)

type pool = {
  mutable pgsql : cqrs list ; 
  mutable size  : int ;
  max_size : int ;
}

(* Lists of connection pools, keyed by (host,port,db) *)
let pools = Hashtbl.create 10 

let get_pool config = 
  let key = (config.host, config.port, config.database) in 
  try false, Hashtbl.find pools key with Not_found ->
    let pool = { pgsql = [] ; size = 0 ; max_size = config.pool_size } in
    Hashtbl.add pools key pool ;
    true, pool 

let get config = 
  let is_first_connection, pool = get_pool config in 
  match pool.pgsql with 
  | [] -> make_cqrs config is_first_connection
  | h :: t -> pool.pgsql <- t ; pool.size <- pool.size - 1 ; h 

let release config cqrs = 

  let _, pool = get_pool config in 
  if pool.size < pool.max_size then begin
    reset_cqrs cqrs ; 
    pool.pgsql <- cqrs :: pool.pgsql ;
    pool.size <- pool.size + 1 ;
  end else begin
    close_cqrs cqrs
  end
  
(* Managing connection lifetime 
   ============================ *)

let using config mkctx thread = 
  let cqrs = get config in
  let ctx  = mkctx cqrs in
  let thread = Run.with_context ctx thread in
  let clean () = release config cqrs in
  Run.finally clean thread
