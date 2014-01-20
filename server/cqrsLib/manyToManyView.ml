(* © 2014 RunOrg *)

open Common
open Std

type ('left, 'right) t = {
  lpack : 'left Pack.packer ;
  lupack : 'left Pack.unpacker ;
  rpack : 'right Pack.packer ;
  rupack : 'right Pack.unpacker ;
  name : string ;
  dbname : (ctx,string) Run.t
}

(* Creating a new map 
   ================== *)

let make (type l) (type r) projection name version left right = 
  
  let module Left = (val left : Fmt.FMT with type t = l) in
  let module Right = (val right : Fmt.FMT with type t = r) in 

  let view = Projection.view projection name version in 
  let dbname = Names.view ~prefix:(Projection.prefix view) name version in 

  let () = Sql.on_first_connection begin 
    let! dbname = dbname in 
    Sql.command ("CREATE TABLE IF NOT EXISTS \"" ^ dbname ^ "\" ( "
		 ^ "\"db\" CHAR(11), "
		 ^ "\"l\" BYTEA, "
		 ^ "\"r\" BYTEA, " 
		 ^ "PRIMARY KEY(\"db\", \"l\", \"r\") "
		 ^ ");") []
  end in 

  view, 
  { name ; dbname ; lpack = Left.pack ; lupack = Left.unpack ; rpack = Right.pack ; rupack = Right.unpack }

(* Adding values to the map 
   ======================== *)

let add map lefts rights = 
  let leftN = List.length lefts and rightN = List.length rights in
  if leftN = 0 || rightN = 0 then return () else 

    let! ctx = Run.context in 
    let! dbname = Run.with_context (ctx :> ctx) map.dbname in 

    let args = 
      [ `Id (ctx # db) ]
      @ List.map (fun l -> `Binary (Pack.to_string map.lpack l)) lefts 
      @ List.map (fun r -> `Binary (Pack.to_string map.rpack r)) rights in

    let query = 
      "INSERT INTO \"" 
      ^ dbname 
      ^ "\" (\"db\",\"l\",\"r\") SELECT DISTINCT $1::char, l.v, r.v FROM (VALUES "
      ^ String.concat "," List.(map (fun i -> !! "($%d::bytea)" (i + 2)) (0 -- leftN)) 
      ^ ") as l(v) CROSS JOIN (VALUES "
      ^ String.concat "," List.(map (fun i -> !! "($%d::bytea)" (i + 2 + leftN)) (0 -- rightN))
      ^ ") as r(v) WHERE NOT EXISTS (SELECT 1 FROM \""
      ^ dbname
      ^ "\" WHERE \"db\" = $1 AND \"l\" = l.v AND \"r\" = r.v)"
    in
    
    Sql.command query args
 
(* Removing values from the map
   ============================ *)

let remove map lefts rights = 
  let leftN = List.length lefts and rightN = List.length rights in 
  if leftN = 0 || rightN = 0 then return () else 

    let! ctx = Run.context in 
    let! dbname = Run.with_context (ctx :> ctx) map.dbname in 

    let args = 
      [ `Id (ctx # db) ]
      @ List.map (fun l -> `Binary (Pack.to_string map.lpack l)) lefts 
      @ List.map (fun r -> `Binary (Pack.to_string map.rpack r)) rights in

    let query = 
      "DELETE FROM \"" 
      ^ dbname 
      ^ "\" WHERE \"db\" = $1 AND \"l\" IN ("
      ^ String.concat "," List.(map (fun i -> !! "$%d" (i + 2)) (0 -- leftN))
      ^ ") AND \"r\" IN ("
      ^ String.concat "," List.(map (fun i -> !! "$%d" (i + 2 + leftN)) (0 -- rightN))
      ^ ")"
    in
    
    Sql.command query args

let delete map left = 

  let! ctx = Run.context in 
  let! dbname = Run.with_context (ctx :> ctx) map.dbname in 
  
  Sql.command ("DELETE FROM \"" ^ dbname ^ "\" WHERE \"db\" = $1 AND \"l\" = $2")
    [ `Id (ctx # db) ; `Binary (Pack.to_string map.lpack left) ] 

(* Testing for existence  
   ===================== *)

let exists map left right = 

  let! ctx = Run.context in 
  let! dbname = Run.with_context (ctx :> ctx) map.dbname in 
  
  let! result = 
    Sql.query ("SELECT 1 FROM \"" ^ dbname ^ "\" WHERE \"db\" = $1 AND \"l\" = $2 AND \"r\" = $3")
    [ `Id (ctx # db) ; `Binary (Pack.to_string map.lpack left) ; `Binary (Pack.to_string map.rpack right) ]
  in
  
  return (Array.length result > 0)
  
(* Listing members 
   =============== *)
	
let list ?(limit=1000) ?(offset=0) map left =

  let! ctx = Run.context in 
  let! dbname = Run.with_context (ctx :> ctx) map.dbname in 

  let! result = Sql.query 
    (!! "SELECT \"r\" FROM \"%s\" WHERE \"db\" = $1 AND \"l\" = $2 ORDER BY \"r\" LIMIT %d OFFSET %d"
	dbname limit offset)
    [ `Id (ctx # db) ; `Binary (Pack.to_string map.lpack left) ] 
  in

  return 
    (List.map
       (fun a -> Pack.of_string map.rupack (Postgresql.unescape_bytea a.(0)))
       (Array.to_list result))

  
