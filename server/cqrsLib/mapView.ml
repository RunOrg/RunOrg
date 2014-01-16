(* © 2013 RunOrg *)

open Common
open Std

module Names = Names

type ('key, 'value) t = {
  kpack  : 'key Pack.packer ;
  kupack : 'key Pack.unpacker ; 
  vpack  : 'value Pack.packer ; 
  vupack : 'value Pack.unpacker ; 
  name   : string ;
  dbname : (ctx, string) Run.t ;
}

(* Creating a new map 
   ================== *)

let create (type k) (type v) name dbname key value = 

  let module Key = (val key : Fmt.FMT with type t = k) in
  let module Value = (val value : Fmt.FMT with type t = v) in 

  let () = Sql.on_first_connection begin 
    let! dbname = dbname in 
    Sql.command ("CREATE TABLE IF NOT EXISTS \"" ^ dbname ^ "\" ( " 
             ^ "\"db\" CHAR(11), "
	     ^ "\"key\" BYTEA, "
	     ^ "\"value\" BYTEA, "
	     ^ "PRIMARY KEY (\"key\") "
	     ^ ");") []
  end in

  { name ; dbname ; kpack = Key.pack ; kupack = Key.unpack ; vpack = Value.pack ; vupack = Value.unpack }

let make projection name version key value = 
  
  let view = Projection.view projection name version in 
  let dbname = Names.view ~prefix:(Projection.prefix view) name version in

  let map = create name dbname key value in
  view, map 

let standalone name version key value = 

  let dbname = Names.view name version in
  create name dbname key value

(* Reading a value from the map
   ============================ *)

let full_get map k = 

  let  k = Pack.to_string map.kpack k in

  let! ctx = Run.context in
  let! dbname = Run.with_context (ctx :> ctx) map.dbname in 
  let! result = Sql.query 
    ("SELECT \"value\" FROM \"" ^ dbname ^ "\" WHERE \"db\" = $1 AND \"key\" = $2") 
    [ `Id (ctx # db) ; `Binary k ] 
  in

  let value = (if Array.length result = 0 then None else 
      Some (Pack.of_string map.vupack (Postgresql.unescape_bytea result.(0).(0)))) in
  
  Run.return (k, ctx # db, dbname, value) 

let get map k =   
  let! _, _, _, r = full_get map k in Run.return r

let exists map k = 
  
  let  k = Pack.to_string map.kpack k in

  let! ctx = Run.context in 
  let! dbname = Run.with_context (ctx :> ctx) map.dbname in 
  let! result = Sql.query 
    ("SELECT 1 FROM \"" ^ dbname ^ "\" WHERE \"db\" = $1 AND \"key\" = $2") [ `Id (ctx # db) ; `Binary k ] in

  return (Array.length result > 0)

(* Updating the map contents
   ========================= *)

let mupdate map k f = 
  
  let! k, db, dbname, v = full_get map k in
  let! r = f v in

  match r with 
  | `Keep   -> Run.return () 
  | `Put v' -> let v' = Pack.to_string map.vpack v' in
	       if v = None then Sql.command
		 ("INSERT INTO \"" ^ dbname ^ "\" (\"db\",\"key\",\"value\") VALUES ($1,$2,$3)")
		 [ `Id db ; `Binary k ; `Binary v' ]
	       else Sql.command 
		 ("UPDATE \"" ^ dbname ^ "\" SET \"value\" = $1 WHERE \"db\" = $2 AND \"key\" = $3")
		 [ `Binary v' ; `Id db ; `Binary k ]
  | `Delete -> Sql.command ("DELETE FROM \"" ^ dbname ^ "\" WHERE \"db\" = $1 AND \"key\" = $2") 
                 [ `Id db ; `Binary k ]

let update map k f = mupdate map k (fun v -> Run.return (f v))		 
		   
(* Querying the map size
   ===================== *)

let count map = 

  let! ctx = Run.context in
  let! dbname = Run.with_context (ctx :> ctx) map.dbname in 
  let! result = Sql.query ("SELECT COUNT(*) FROM \"" ^ dbname ^ "\" WHERE \"db\" = $1") [ `Id (ctx # db) ] in
  Run.return (Option.default 0 (Result.int result))

(* Querying all values 
   =================== *)

let all ?(limit=1000) ?(offset=0) map = 
  
  let! ctx = Run.context in 
  let! dbname = Run.with_context (ctx :> ctx) map.dbname in 
  let! result = Sql.query 
    (!! "SELECT \"key\", \"value\" FROM \"%s\" ORDER BY \"key\" WHERE \"db\" = $1 LIMIT %d OFFSET %d" 
	dbname limit offset) 
    [ `Id (ctx # db) ] in
  
  Run.return 
    (List.map 
       (fun a -> let key = Pack.of_string map.kupack (Postgresql.unescape_bytea a.(0)) in
		 let value = Pack.of_string map.vupack (Postgresql.unescape_bytea a.(1)) in
		 (key, value))
       (Array.to_list result))
