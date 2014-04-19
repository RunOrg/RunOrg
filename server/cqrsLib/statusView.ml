(* © 2014 RunOrg *)

open Common
open Std

type ('key, 'status) t = {
  kpack  : 'key Pack.packer ;
  kupack : 'key Pack.unpacker ; 
  spack  : 'status Pack.packer ; 
  supack : 'status Pack.unpacker ; 
  dflt   : 'status ; 
  name   : string ;
  wait   : (ctx, unit) Run.t ; 
  dbname : (ctx, string) Run.t ;
}

(* Creating a new map 
   ================== *)

let make (type k) (type s) projection name version dflt key status = 

  let view = Projection.view projection name version in 
  let dbname = Names.view ~prefix:(Projection.prefix view) name version in
  let wait = Projection.wait projection in 

  let module Key = (val key : Fmt.FMT with type t = k) in
  let module Status = (val status : Fmt.FMT with type t = s) in 

  let () = Sql.on_first_connection begin 
    let! dbname = dbname in 
    let! () = Sql.command ("CREATE TABLE IF NOT EXISTS \"" ^ dbname ^ "\" ( " 
             ^ "\"db\" CHAR(11), "
	     ^ "\"key\" BYTEA, "
	     ^ "\"status\" BYTEA, "
	     ^ "PRIMARY KEY (\"db\",\"key\") "
	     ^ ");") [] in
    return () 
    (* Sql.command 
       ("CREATE INDEX \"" ^ dbname ^ "/db,status\" ON \"" ^ dbname ^ "\" (\"status\",\"db\")") [] *)
  end in

  view, { name ; dbname ; wait ; dflt ; 
	  kpack = Key.pack ; kupack = Key.unpack ; spack = Status.pack ; supack = Status.unpack }

(* Reading a status from the map
   ============================= *)

let full_get map k = 

  let  k = Pack.to_string map.kpack k in

  let! ctx = Run.context in
  let! ()  = Run.with_context (ctx :> ctx) map.wait in 
  let! dbname = Run.with_context (ctx :> ctx) map.dbname in 
  let! result = Sql.query 
    ("SELECT \"status\" FROM \"" ^ dbname ^ "\" WHERE \"db\" = $1 AND \"key\" = $2") 
    [ `Id (ctx # db) ; `Binary k ] 
  in

  let status = (if Array.length result = 0 then map.dflt else 
      Pack.of_string map.supack (Postgresql.unescape_bytea result.(0).(0))) in
  
  return (k, ctx # db, dbname, status) 

let get map k =   
  let! _, _, _, r = full_get map k in return r


(* Updating the map contents
   ========================= *)

let update map k f = 
  
  let! k, db, dbname, s = full_get map k in
  let s' = f s in

  if s = s' then return () else

    if s' = map.dflt then
      Sql.command ("DELETE FROM \"" ^ dbname ^ "\" WHERE \"db\" = $1 AND \"key\" = $2") 
        [ `Id db ; `Binary k ]
    else 
      let sbin = Pack.to_string map.spack s' in
      if s = map.dflt then 
	Sql.command
	  ("INSERT INTO \"" ^ dbname ^ "\" (\"db\",\"key\",\"status\") VALUES ($1,$2,$3)")
	  [ `Id db ; `Binary k ; `Binary sbin ]
      else 
	Sql.command 
	  ("UPDATE \"" ^ dbname ^ "\" SET \"status\" = $1 WHERE \"db\" = $2 AND \"key\" = $3")
	  [ `Binary sbin ; `Id db ; `Binary k ]
	  

(* Querying all values 
   =================== *)

let global_by_status ?(limit=1000) ?(offset=0) map status = 
  
  let! ctx = Run.context in 
  let! ()  = Run.with_context (ctx :> ctx) map.wait in 
  let! dbname = Run.with_context (ctx :> ctx) map.dbname in

  let! result = Sql.query 
    (!! "SELECT \"db\", \"key\" FROM \"%s\" WHERE \"status\" = $1 ORDER BY \"key\" LIMIT %d OFFSET %d" 
	dbname limit offset) 
    [ `Binary (Pack.to_string map.spack status) ] in
  
  Run.return 
    (List.map 
       (fun a -> let id = Id.of_string a.(0) in
		 let key = Pack.of_string map.kupack (Postgresql.unescape_bytea a.(1)) in
		 (id, key))
       (Array.to_list result))

