(* © 2014 RunOrg *)

open Std
open Common

type ('key,'value) t = {
  kpack : 'key Pack.packer ;
  kupack : 'key Pack.unpacker ;
  vpack : 'value Pack.packer ;
  vupack : 'value Pack.unpacker ; 
  name : string ; 
  wait : (ctx,unit) Run.t ; 
  dbname : (ctx,string) Run.t
}

(* Creating a new set 
   ================== *)

let make (type k) (type v) projection name version key value = 
  
  let module Key = (val key : Fmt.FMT with type t = k) in
  let module Value = (val value : Fmt.FMT with type t = v) in 

  let view = Projection.view projection name version in 
  let dbname = Names.view ~prefix:(Projection.prefix view) name version in 
  
  let () = Sql.on_first_connection begin 
    let! dbname = dbname in 
    Sql.command ("CREATE TABLE IF NOT EXISTS \"" ^ dbname ^ "\" ( "
		 ^ "\"db\" CHAR(11), "
		 ^ "\"k\" BYTEA, "
		 ^ "\"v\" BYTEA, " 
		 ^ "PRIMARY KEY(\"db\",\"k\",\"v\") "
		 ^ ");") [] 
  end in 

  let wait = Projection.wait projection in 
  
  view, 
  { name ; dbname ; wait ; 
    kpack = Key.pack ; kupack = Key.unpack ; vpack = Value.pack ; vupack = Value.unpack }

(* Adding values to the set 
   ======================== *)

let add set key values = 
  let valueN = List.length values in 
  if valueN = 0 then return () else
   
    let! ctx = Run.context in 
    let! dbname = Run.with_context (ctx :> ctx) set.dbname in 

    let args  = `Id (ctx # db) :: `Binary (Pack.to_string set.kpack key) 
      :: List.map (fun v -> `Binary (Pack.to_string set.vpack v)) values in 

    let query = 
      "INSERT INTO \""
      ^ dbname
      ^ "\" (\"db\",\"k\",\"v\") SELECT DISTINCT $1::CHAR(11), $2::bytea, * FROM (VALUES "
      ^ String.concat "," List.(map (fun i -> !! "($%d::bytea)" (i+3)) (0 -- valueN))
      ^ ") as v(key) WHERE NOT EXISTS (SELECT 1 FROM \"" 
      ^ dbname
      ^ "\" WHERE \"db\" = $1 AND \"k\" = $2 AND \"v\" = v.key)"
    in

    Sql.command query args

(* Removing values from the set
   ============================ *)

let remove set key values = 
  let valueN = List.length values in 
  if valueN = 0 then return () else
   
    let! ctx = Run.context in 
    let! dbname = Run.with_context (ctx :> ctx) set.dbname in 

    let args  = `Id (ctx # db) :: `Binary (Pack.to_string set.kpack key) 
      ::List.map (fun v -> `Binary (Pack.to_string set.vpack v)) values in
 
    let query = 
      "DELETE FROM \""
      ^ dbname
      ^ "\" WHERE \"db\" = $1 AND \"k\" = $2 AND \"v\" IN ("
      ^ String.concat "," List.(map (fun i -> !! "$%d" (i+3)) (0 -- valueN))
      ^ ")"
    in

    Sql.command query args

let delete set key = 
   
    let! ctx = Run.context in 
    let! dbname = Run.with_context (ctx :> ctx) set.dbname in 

    let args = [ `Id (ctx # db) ; `Binary (Pack.to_string set.kpack key) ] in
    let query = "DELETE FROM \"" ^ dbname ^ "\" WHERE \"db\" = $1 AND \"k\" = $2" in

    Sql.command query args

(* Testing for existence 
   ===================== *)

let exists set key value = 
  
  let! ctx = Run.context in 
  let! ()  = Run.with_context (ctx :> ctx) set.wait in 
  let! dbname = Run.with_context (ctx :> ctx) set.dbname in 
    
  let! result = 
    Sql.query ("SELECT 1 FROM \"" ^ dbname ^"\" WHERE \"db\" = $1 AND \"k\" = $2 AND \"v\" = $3")
      [ `Id (ctx # db) ; `Binary (Pack.to_string set.kpack key) ; `Binary (Pack.to_string set.vpack value) ] 
  in

  return (Array.length result > 0)

let intersect set key values = 

  let! ctx = Run.context in 
  let! ()  = Run.with_context (ctx :> ctx) set.wait in 
  let! dbname = Run.with_context (ctx :> ctx) set.dbname in 
  
  let map = 
    List.fold_left (fun map value -> Map.add (Pack.to_string set.vpack value) value map) Map.empty values in
  
  let values = Map.foldi (fun k _ l -> k :: l) map [] in
  let valueN = List.length values in

  if valueN = 0 then return [] else

    let query  = "SELECT \"v\" FROM \"" ^ dbname ^ "\" WHERE \"db\" = $1 AND \"k\" = $2 AND \"v\" IN ("
      ^ String.concat "," List.(map (fun i -> !! "$%d" (i+3)) (0 -- valueN))
      ^ ")" in

    let args = 
      `Id (ctx # db) :: `Binary (Pack.to_string set.kpack key) :: List.map (fun v -> `Binary v) values in

    let! result = Sql.query query args in 
    
    return (List.filter_map 
	      (fun a -> let value = Postgresql.unescape_bytea a.(0) in
			try Some (Map.find value map) with Not_found -> None)
	      (Array.to_list result))

