(* © 2014 RunOrg *)

open Common
open Std

type ('key, 'id, 'value) t = {
  kpack : 'key Pack.packer ; 
  kupack : 'key Pack.unpacker ;
  ipack : 'id Pack.packer ;
  iupack : 'id Pack.unpacker ;
  vpack : 'value Pack.packer ;
  vupack : 'value Pack.unpacker ;
  name : string ;
  dbname : (ctx, string) Run.t
}

(* Creating a new feed map 
   ======================= *)

let make (type k) (type i) (type v) projection name version key id value = 
  
  let view = Projection.view projection name version in 
  let dbname = Names.view ~prefix:(Projection.prefix view) name version in 

  let module Key = (val key : Fmt.FMT with type t = k) in
  let module Id = (val id : Fmt.FMT with type t = i) in
  let module Value = (val value : Fmt.FMT with type t = v) in

  let () = Sql.on_first_connection begin 
    let! dbname = dbname in 
    Sql.command ("CREATE TABLE IF NOT EXISTS \"" ^ dbname ^ "\" ( "
		 ^ "\"db\" CHAR(11), "
		 ^ "\"key\" BYTEA, "
		 ^ "\"id\" BYTEA, "
		 ^ "\"value\" BYTEA, "
		 ^ "\"t\" CHAR(14), "
		 ^ "PRIMARY KEY (\"db\",\"key\",\"id\") "
		 ^ ");") []
  end in 
  
  view, { name ; dbname ; 
    kpack = Key.pack ; kupack = Key.unpack ;
    ipack = Id.pack ; iupack = Id.unpack ;
    vpack = Value.pack ; vupack = Value.unpack }

(* Reading an item from the map
   ========================= *)

let full_get map k i = 

  let  k = Pack.to_string map.kpack k in 
  let  i = Pack.to_string map.ipack i in 
  
  let! ctx = Run.context in 
  let! dbname = Run.with_context (ctx :> ctx) map.dbname in 
  let! result = Sql.query 
    ("SELECT \"t\", \"value\" FROM \"" ^ dbname ^ "\" WHERE \"db\" = $1 AND \"key\" = $2 AND \"id\" = $3")
    [ `Id (ctx # db) ; `Binary k ; `Binary i ]
  in

  let found = (if Array.length result = 0 then None else
      match Time.of_compact result.(0).(0) with None -> None | Some time -> 
      Some (time, Pack.of_string map.vupack (Postgresql.unescape_bytea result.(0).(1)))) in
  
  Run.return (k, i, ctx # db, dbname, found)

let get map k i = 
  let! _, _, _, _, r = full_get map k i in return r

let exists map k i = 
  
  let  k = Pack.to_string map.kpack k in 
  let  i = Pack.to_string map.ipack i in 
  
  let! ctx = Run.context in 
  let! dbname = Run.with_context (ctx :> ctx) map.dbname in 
  let! result = Sql.query 
    ("SELECT 1 FROM \"" ^ dbname ^ "\" WHERE \"db\" = $1 AND \"key\" = $2 AND \"id\" = $3")
    [ `Id (ctx # db) ; `Binary k ; `Binary i ]
  in

  return (Array.length result > 0)

(* Updating the map contents 
   ========================= *)

let mupdate map k i f = 
  
  let! k, i, db, dbname, found = full_get map k i in 
  let! r = f found in 

  match r with 
  | `Keep -> return () 
  | `Delete -> 
    Sql.command 
      ("DELETE FROM \"" ^ dbname ^ "\" WHERE \"db\" = $1 AND \"key\" = $2 AND \"id\" = $3")
      [ `Id db ; `Binary k ; `Binary i ]
  | `Put (t, v) -> 
    let v = Pack.to_string map.vpack v in 
    let t = Time.to_compact t in 
    if found = None then Sql.command
      ("INSERT INTO \"" ^ dbname ^ "\" (\"db\",\"key\",\"id\",\"t\",\"value\") VALUES ($1,$2,$3,$4,$5)")
      [ `Id db ; `Binary k ; `Binary i ; `String t ; `Binary v ]
    else Sql.command
      ("UPDATE \"" ^ dbname ^ "\" SET \"t\" = $4, \"value\" = $5 WHERE \"db\" = $1 AND \"key\" = $2 " 
       ^ "AND \"id\" = $3")
      [ `Id db ; `Binary k ; `Binary i ; `String t ; `Binary v ]

let update map k i f = mupdate map k i (fun v -> return (f v))

(* Gathering stats for a key. 
   ========================== *)

let stats map k = 

  let  k = Pack.to_string map.kpack k in 
  
  let! ctx = Run.context in 
  let! dbname = Run.with_context (ctx :> ctx) map.dbname in 

  let! result = Sql.query 
    ("SELECT COUNT(*), MIN(\"t\"), MAX(\"t\") FROM \"" ^ dbname ^ "\"WHERE \"db\" = $1 AND \"key\" = $2")
    [ `Id (ctx # db) ; `Binary k ]
  in

  let count = int_of_string result.(0).(0) in
  let first, last = 
    if count = 0 then None, None else 
      Time.of_compact result.(0).(1), Time.of_compact result.(0).(2)
  in

  return (object
    method count = count
    method first = first
    method last  = last 
  end)

(* Extracting feed values 
   ====================== *)

let list map ?(limit=1000) ?(offset=0) k = 

  let  k = Pack.to_string map.kpack k in 
  
  let! ctx = Run.context in 
  let! dbname = Run.with_context (ctx :> ctx) map.dbname in 

  let! result = Sql.query 
    (!! "SELECT \"id\", \"t\", \"value\" FROM \"%s\" WHERE \"db\" = $1 AND \"key\" = $2 
         ORDER BY \"t\" LIMIT %d OFFSET %d" dbname limit offset)
    [ `Id (ctx # db) ; `Binary k ]
  in
  
  return 
    (List.filter_map 
       (fun a -> let id = Pack.of_string map.iupack (Postgresql.unescape_bytea a.(0)) in
		 let time = Time.of_compact a.(1) in
		 let value = Pack.of_string map.vupack (Postgresql.unescape_bytea a.(2)) in
		 match time with None -> None | Some time -> Some (id, time, value))
       (Array.to_list result))
    
