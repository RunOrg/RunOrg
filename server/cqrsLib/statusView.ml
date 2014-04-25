(* © 2014 RunOrg *)

open Common
open Std

type ('set, 'key, 'status) t = {
  spack   : 'set Pack.packer ;
  supack  : 'set Pack.unpacker ; 
  kpack   : 'key Pack.packer ;
  kupack  : 'key Pack.unpacker ; 
  stpack  : 'status Pack.packer ; 
  stupack : 'status Pack.unpacker ; 
  dflt    : 'status ; 
  name    : string ;
  wait    : (ctx, unit) Run.t ; 
  dbname  : (ctx, string) Run.t ;
}

(* Creating a new map 
   ================== *)

let make (type s) (type k) (type st) projection name version dflt set key status = 

  let view = Projection.view projection name version in 
  let dbname = Names.view ~prefix:(Projection.prefix view) name version in
  let wait = Projection.wait projection in 

  let module Set = (val set : Fmt.FMT with type t = s) in
  let module Key = (val key : Fmt.FMT with type t = k) in
  let module Status = (val status : Fmt.FMT with type t = st) in 

  let () = Sql.on_first_connection begin 
    let! dbname = dbname in 
    let! () = Sql.command ("CREATE TABLE IF NOT EXISTS \"" ^ dbname ^ "\" ( " 
             ^ "\"db\" CHAR(11), "
	     ^ "\"set\" BYTEA, "
	     ^ "\"key\" BYTEA, "
	     ^ "\"status\" BYTEA, "
	     ^ "PRIMARY KEY (\"db\",\"set\", \"key\") "
	     ^ ");") [] in
    return () 
    (* Sql.command 
       ("CREATE INDEX \"" ^ dbname ^ "/db,status\" ON \"" ^ dbname ^ "\" (\"status\",\"db\")") [] *)
  end in

  view, { name ; dbname ; wait ; dflt ; 
	  spack = Set.pack ; supack = Set.unpack ; 
	  kpack = Key.pack ; kupack = Key.unpack ; 
	  stpack = Status.pack ; stupack = Status.unpack }

(* Reading a status from the map
   ============================= *)

let full_get map s k = 

  let  s = Pack.to_string map.spack s in 
  let  k = Pack.to_string map.kpack k in

  let! ctx = Run.context in
  let! ()  = Run.with_context (ctx :> ctx) map.wait in 
  let! dbname = Run.with_context (ctx :> ctx) map.dbname in 
  let! result = Sql.query 
    ("SELECT \"status\" FROM \"" ^ dbname ^ "\" WHERE \"db\" = $1 AND \"set\" = $2 AND \"key\" = $3") 
    [ `Id (ctx # db) ; `Binary s ; `Binary k ] 
  in

  let status = (if Array.length result = 0 then map.dflt else 
      Pack.of_string map.stupack (Postgresql.unescape_bytea result.(0).(0))) in
  
  return (s, k, ctx # db, dbname, status) 

let get map s k =   
  let! _, _, _, _, r = full_get map s k in return r

(* Updating the map contents
   ========================= *)

let update map s k f = 
  
  let! s, k, db, dbname, st = full_get map s k in
  let st' = f st in

  if st = st' then return () else

    if st' = map.dflt then
      Sql.command ("DELETE FROM \"" ^ dbname ^ "\" WHERE \"db\" = $1 AND \"set\" = $2 AND \"key\" = $3") 
        [ `Id db ; `Binary s ; `Binary k ]
    else 
      let stbin = Pack.to_string map.stpack st' in
      if st = map.dflt then 
	Sql.command
	  ("INSERT INTO \"" ^ dbname ^ "\" (\"db\",\"set\",\"key\",\"status\") VALUES ($1,$2,$3,$4)")
	  [ `Id db ; `Binary s ; `Binary k ; `Binary stbin ]
      else 
	Sql.command 
	  ("UPDATE \"" ^ dbname ^ "\" SET \"status\" = $1 WHERE \"db\" = $2 AND \"set\" = $3 AND \"key\" = $4")
	  [ `Binary stbin ; `Id db ; `Binary s ; `Binary k ]
	  
(* Counting sets 
   ============= *)

let count map set = 

  let s = Pack.to_string map.spack set in

  let! ctx = Run.context in
  let! ()  = Run.with_context (ctx :> ctx) map.wait in 
  let! dbname = Run.with_context (ctx :> ctx) map.dbname in 

  let! result = Sql.query
    ("SELECT \"status\", COUNT(*) FROM \""^dbname^"\" WHERE \"db\" = $1 AND \"set\" = $2 GROUP BY \"status\"")
    [ `Id (ctx # db) ; `Binary s ] in

  return 
    (Map.of_list 
       (List.map 
	  (fun a -> let s = Pack.of_string map.stupack (Postgresql.unescape_bytea a.(0)) in
		    let n = int_of_string a.(1) in
		    s, n)
	  (Array.to_list result)))
       
(* Querying all values 
   =================== *)

let global_by_status ?(limit=1000) ?(offset=0) map status = 
  
  let! ctx = Run.context in 
  let! ()  = Run.with_context (ctx :> ctx) map.wait in 
  let! dbname = Run.with_context (ctx :> ctx) map.dbname in

  let! result = Sql.query 
    (!! "SELECT \"db\", \"set\", \"key\" FROM \"%s\" WHERE \"status\" = $1 ORDER BY \"key\" LIMIT %d OFFSET %d" 
	dbname limit offset) 
    [ `Binary (Pack.to_string map.stpack status) ] in
  
  Run.return 
    (List.map 
       (fun a -> let id = Id.of_string a.(0) in
		 let set = Pack.of_string map.supack (Postgresql.unescape_bytea a.(1)) in
		 let key = Pack.of_string map.kupack (Postgresql.unescape_bytea a.(2)) in
		 (id, set, key))
       (Array.to_list result))

