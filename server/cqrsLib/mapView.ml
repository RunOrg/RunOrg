open Common

module Names = Names

type ('key, 'value) t = {
  kpack  : 'key Pack.packer ;
  vpack  : 'value Pack.packer ; 
  vupack : 'value Pack.unpacker ; 
  name   : string ;
  dbname : (ctx, string) Run.t ;
}

(* Creating a new map 
   ================== *)

let make (type k) (type v) ?projection name version key value = 

  let dbname = Names.map ?projection name version in

  let module Key = (val key : Fmt.FMT with type t = k) in
  let module Value = (val value : Fmt.FMT with type t = v) in 

  let () = run_on_first_connection begin 
    let! dbname = dbname in 
    command ("CREATE TABLE IF NOT EXISTS \"" ^ dbname ^ "\" ( " 
	     ^ "\"key\" BYTEA, "
	     ^ "\"value\" BYTEA, "
	     ^ "PRIMARY KEY (\"key\") "
	     ^ ");") []
  end in

  { name ; dbname ; kpack = Key.pack ; vpack = Value.pack ; vupack = Value.unpack }

(* Reading a value from the map
   ============================ *)

let full_get map k = 

  let  k = Pack.to_string map.kpack k in

  let! dbname = Run.edit_context (fun ctx -> (ctx :> ctx)) map.dbname in 
  let! result = query 
    ("SELECT \"value\" FROM \"" ^ dbname ^ "\" WHERE \"key\" = $1") [ `Binary k ] in

  let value = (if Array.length result = 0 then None else 
      Some (Pack.of_string map.vupack (Postgresql.unescape_bytea result.(0).(0)))) in
  
  Run.return (k, dbname, value) 

let get map k =   
  let! _, _, r = full_get map k in Run.return r

(* Updating the map contents
   ========================= *)

let mupdate map k f = 
  
  let! k, dbname, v = full_get map k in
  let! r = f v in

  match r with 
  | `Keep   -> Run.return () 
  | `Put v' -> let v' = Pack.to_string map.vpack v' in
	       if v = None then command
		 ("INSERT INTO \"" ^ dbname ^ "\" (\"key\",\"value\") VALUES ($1,$2)")
		 [ `Binary k ; `Binary v' ]
	       else command 
		 ("UPDATE \"" ^ dbname ^ "\" SET \"value\" = $1 WHERE \"key\" = $2")
		 [ `Binary v' ; `Binary k ]
  | `Delete -> command ("DELETE FROM \"" ^ dbname ^ "\" WHERE \"key\" = $1") [ `Binary k ]

let update map k f = mupdate map k (fun v -> Run.return (f v))		 
		   
    
