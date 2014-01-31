(* © 2014 RunOrg *)

open Std
open Common

type 'key t = {
  pack : 'key Pack.packer ;
  upack : 'key Pack.unpacker ;
  name : string ; 
  wait : (ctx,unit) Run.t ; 
  dbname : (ctx,string) Run.t
}

(* Creating a new set 
   ================== *)

let make (type k) projection name version key = 
  
  let module Key = (val key : Fmt.FMT with type t = k) in

  let view = Projection.view projection name version in 
  let dbname = Names.view ~prefix:(Projection.prefix view) name version in 
  
  let () = Sql.on_first_connection begin 
    let! dbname = dbname in 
    Sql.command ("CREATE TABLE IF NOT EXISTS \"" ^ dbname ^ "\" ( "
		 ^ "\"db\" CHAR(11), "
		 ^ "\"k\" BYTEA, "
		 ^ "PRIMARY KEY(\"db\",\"k\") "
		 ^ ");") [] 
  end in 

  let wait = Projection.wait projection in 
  
  view, 
  { name ; dbname ; wait ; pack = Key.pack ; upack = Key.unpack }

(* Adding values to the set 
   ======================== *)

let add set keys = 
  let keyN = List.length keys in 
  if keyN = 0 then return () else
   
    let! ctx = Run.context in 
    let! dbname = Run.with_context (ctx :> ctx) set.dbname in 

    let args  = `Id (ctx # db) :: List.map (fun k -> `Binary (Pack.to_string set.pack k)) keys in 
    let query = 
      "INSERT INTO \""
      ^ dbname
      ^ "\" (\"db\",\"k\") SELECT DISTINCT $1::CHAR(11), * FROM (VALUES "
      ^ String.concat "," List.(map (fun i -> !! "($%d::bytea)" (i+2)) (0 -- keyN))
      ^ ") as v(key) WHERE NOT EXISTS (SELECT 1 FROM \"" 
      ^ dbname
      ^ "\" WHERE \"db\" = $1 AND \"k\" = v.key)"
    in

    Sql.command query args

(* Removing values from the set
   ============================ *)

let remove set keys = 
  let keyN = List.length keys in 
  if keyN = 0 then return () else
   
    let! ctx = Run.context in 
    let! dbname = Run.with_context (ctx :> ctx) set.dbname in 

    let args  = `Id (ctx # db) :: List.map (fun k -> `Binary (Pack.to_string set.pack k)) keys in 
    let query = 
      "DELETE FROM \""
      ^ dbname
      ^ "\" WHERE \"db\" = $1 AND \"k\" IN ("
      ^ String.concat "," List.(map (fun i -> !! "$%d" (i+2)) (0 -- keyN))
      ^ ")"
    in

    Sql.command query args

(* Testing for existence 
   ===================== *)

let exists set key = 
  
  let! ctx = Run.context in 
  let! ()  = Run.with_context (ctx :> ctx) set.wait in 
  let! dbname = Run.with_context (ctx :> ctx) set.dbname in 
    
  let! result = 
    Sql.query (!! "SELECT 1 FROM \"%s\" WHERE \"db\" = $1 AND \"k\" = $2" dbname)
      [ `Id (ctx # db) ; `Binary (Pack.to_string set.pack key) ] in

  return (Array.length result > 0)
