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

(* Creating a new index 
   ==================== *)

let make (type k) projection name version key = 
  
  let module Key = (val key : Fmt.FMT with type t = k) in

  let view = Projection.view projection name version in 
  let dbname = Names.view ~prefix:(Projection.prefix view) name version in 
  
  let () = Sql.on_first_connection begin 
    let! dbname = dbname in 
    Sql.command ("CREATE TABLE IF NOT EXISTS \"" ^ dbname ^ "\" ( "
		 ^ "\"db\" CHAR(11), "
		 ^ "\"k\" BYTEA, "
		 ^ "\"word\" TEXT, "
		 ^ "PRIMARY KEY(\"db\",\"word\",\"k\") "
		 ^ ");") [] 
  end in 

  let wait = Projection.wait projection in 
  
  view, 
  { name ; dbname ; wait ; pack = Key.pack ; upack = Key.unpack }

(* Binding values to words
   ======================= *)

let set index key words =

  let! ctx = Run.context in 
  let! dbname = Run.with_context (ctx :> ctx) index.dbname in 

  let k = Pack.to_string index.pack key in

  let! () = Sql.command 
    ("DELETE FROM \"" ^ dbname ^ "\" WHERE \"db\" = $1 AND \"k\" = $2")
    [ `Id (ctx # db) ; `Binary k ] in

  let words = List.sort_unique compare words in 
  
  let wordN = List.length words in 
  if wordN = 0 then return () else
   
    let args  = `Id (ctx # db) :: `Binary k :: List.map (fun w -> `String w) words in
    let query = 
      "INSERT INTO \""
      ^ dbname
      ^ "\" (\"db\",\"k\",\"word\") VALUES ("
      ^ String.concat "," List.(map (fun i -> !! "($1,$2,$%d::bytea)" (i+3)) (0 -- wordN))
      ^ ")"
    in

    Sql.command query args

(* Searching for prefix
   ==================== *)

let find ?(limit=10) index prefix = 
  
  let! ctx = Run.context in 
  let! dbname = Run.with_context (ctx :> ctx) index.dbname in 
  
  let prefix = String.escape '\\' ['\'';'\\';'%';'_'] prefix in
    
  let! result = Sql.query 
    (!! "SELECT DISTINCT \"k\" FROM \"%s\" WHERE \"db\" = $1 AND \"word\" ~~ '%s%%' LIMIT %d" 
	dbname prefix limit) 
    [ `Id (ctx # db ) ] in
  
  return (List.map (fun a -> Pack.of_string index.upack (Postgresql.unescape_bytea a.(0)))
	    (Array.to_list result))

(* Searching for word
   ================== *)

let find_exact ?(limit=10) index word = 
  
  let! ctx = Run.context in 
  let! dbname = Run.with_context (ctx :> ctx) index.dbname in 
      
  let! result = Sql.query 
    (!! "SELECT DISTINCT \"k\" FROM \"%s\" WHERE \"db\" = $1 AND \"word\" = $2 %d" 
	dbname limit) 
    [ `Id (ctx # db ) ; `String word ] in
  
  return (List.map (fun a -> Pack.of_string index.upack (Postgresql.unescape_bytea a.(0)))
	    (Array.to_list result))

