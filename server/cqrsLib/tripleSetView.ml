(* © 2014 RunOrg *)

open Common
open Std

type ('a, 'b, 'c) t = {
  apack : 'a Pack.packer ;
  aupack : 'a Pack.unpacker ;
  bpack : 'b Pack.packer ;
  bupack : 'b Pack.unpacker ;
  cpack : 'c Pack.packer ;
  cupack : 'c Pack.unpacker ;
  name : string ;
  wait : (ctx,unit) Run.t ; 
  a : string ;
  b : string ;
  c : string ; 
  dbname : (ctx,string) Run.t 
}

(* Creating a new map 
   ================== *)

let make (type a) (type b) (type c) projection name version aT bT cT = 
  
  let module A = (val aT : Fmt.FMT with type t = a) in
  let module B = (val bT : Fmt.FMT with type t = b) in
  let module C = (val cT : Fmt.FMT with type t = c) in

  let view = Projection.view projection name version in 
  let dbname = Names.view ~prefix:(Projection.prefix view) name version in 

  let () = Sql.on_first_connection begin 
    let! dbname = dbname in 
    Sql.command ("CREATE TABLE IF NOT EXISTS \"" ^ dbname ^ "\" ( "
		 ^ "\"db\" CHAR(11), "
		 ^ "\"a\" BYTEA, "
		 ^ "\"b\" BYTEA, " 
		 ^ "\"c\" BYTEA, " 
		 ^ "PRIMARY KEY(\"db\", \"a\", \"b\", \"c\") "
		 ^ ");") []
  end in 

  let wait = Projection.wait projection in 

  view, 
  { name ; dbname ; wait ; a = "\"a\"" ; b = "\"b\"" ; c = "\"c\"" ; 
    apack = A.pack ; aupack = A.unpack ; 
    bpack = B.pack ; bupack = B.unpack ; 
    cpack = C.pack ; cupack = C.unpack }

let flipBC map = 
  { name   = map.name ;
    dbname = map.dbname ;
    apack  = map.apack ;
    aupack = map.aupack ;
    bpack  = map.cpack ;
    bupack = map.cupack ;
    cpack  = map.bpack ;
    cupack = map.bupack ;
    wait   = map.wait ;
    a      = map.a ;
    b      = map.c ;
    c      = map.b }

let flipAB map = 
  { name   = map.name ;
    dbname = map.dbname ;
    apack  = map.bpack ;
    aupack = map.bupack ;
    bpack  = map.apack ;
    bupack = map.aupack ;
    cpack  = map.cpack ;
    cupack = map.cupack ;
    wait   = map.wait ;
    a      = map.b ;
    b      = map.a ;
    c      = map.c }

let abc map = map.a, map.b, map.c

(* Adding values to the map 
   ======================== *)

let add map a b cs =
  let cN = List.length cs in
  if cN = 0 then return () else 

    let! ctx = Run.context in 
    let! dbname = Run.with_context (ctx :> ctx) map.dbname in 

    let args = 
      `Id (ctx # db) :: `Binary (Pack.to_string map.apack a) :: `Binary (Pack.to_string map.bpack b) 
      :: List.map (fun c -> `Binary (Pack.to_string map.cpack c)) cs in

    let query = 
      "INSERT INTO \"" 
      ^ dbname 
      ^ "\" (\"db\","^map.a^","^map.b^","^map.c^") "
      ^ "SELECT DISTINCT $1::char(11), $2::bytea, $3::bytea, c.v FROM (VALUES "
      ^ String.concat "," List.(map (fun i -> !! "($%d::bytea)" (i + 4)) (0 -- cN)) 
      ^ ") as c(v) WHERE NOT EXISTS (SELECT 1 FROM \""
      ^ dbname
      ^ "\" WHERE \"db\" = $1 AND "^map.a^" = $2 AND "^map.b^" = $3 AND "^map.c^" = c.v)"
    in
    
    Sql.command query args
 
(* Removing values from the map
   ============================ *)

let remove map a b cs = 
  let cN = List.length cs in
  if cN = 0 then return () else 

    let! ctx = Run.context in 
    let! dbname = Run.with_context (ctx :> ctx) map.dbname in 

    let args = 
      `Id (ctx # db) :: `Binary (Pack.to_string map.apack a) :: `Binary (Pack.to_string map.bpack b)
      :: List.map (fun c -> `Binary (Pack.to_string map.cpack c)) cs in

    let query = 
      "DELETE FROM \"" 
      ^ dbname 
      ^ "\" WHERE \"db\" = $1 AND "^map.a^" = $2 AND "^map.b^" = $3 AND "^map.c^" IN ("
      ^ String.concat "," List.(map (fun i -> !! "$%d" (i + 4)) (0 -- cN))
      ^ ")"
    in
    
    Sql.command query args

let delete map a = 

  let! ctx = Run.context in 
  let! dbname = Run.with_context (ctx :> ctx) map.dbname in 

  Sql.command ("DELETE FROM \"" ^ dbname ^ "\" WHERE \"db\" = $1 AND "^map.a^" = $2")
    [ `Id (ctx # db) ; `Binary (Pack.to_string map.apack a) ] 

let delete2 map a b = 

  let! ctx = Run.context in 
  let! dbname = Run.with_context (ctx :> ctx) map.dbname in 

  Sql.command ("DELETE FROM \"" ^ dbname ^ "\" WHERE \"db\" = $1 AND "^map.a^" = $2 AND "^map.b^" = $3")
    [ `Id (ctx # db) ; `Binary (Pack.to_string map.apack a) ; 
      `Binary (Pack.to_string map.bpack b) ] 

(* Testing for existence  
   ===================== *)

let intersect map a b cs = 

  let cN = List.length cs in 
  if cN = 0 then return [] else 

    let! ctx = Run.context in 
    let! ()  = Run.with_context (ctx :> ctx) map.wait in 
    let! dbname = Run.with_context (ctx :> ctx) map.dbname in 
    
    let args = 
      `Id (ctx # db) :: `Binary (Pack.to_string map.apack a) :: `Binary (Pack.to_string map.bpack b) 
      :: List.map (fun c -> `Binary (Pack.to_string map.cpack c)) cs 
    in

    let! result = 
      Sql.query ("SELECT "^map.c^" FROM \"" ^ dbname ^ "\" WHERE \"db\" = $1 AND "
		 ^map.a^" = $2 AND "^map.b^" = $3 AND "^map.c^" IN ("
		 ^String.concat "," List.(map (fun i -> !! "$%d" (i + 4)) (0 -- cN))
		 ^")")
	args
    in
  
    return 
      (List.map
	 (fun a -> Pack.of_string map.cupack (Postgresql.unescape_bytea a.(0)))
	 (Array.to_list result))

(* Listing members 
   =============== *)
	
let all map ?(limit=1000) ?(offset=0) a =

  let! ctx = Run.context in 
  let! ()  = Run.with_context (ctx :> ctx) map.wait in 
  let! dbname = Run.with_context (ctx :> ctx) map.dbname in 

  let! result = Sql.query 
    ("SELECT "^map.b^","^map.c^" FROM \""^dbname^"\" "
     ^ "WHERE \"db\" = $1 AND "^map.a^" = $2 ORDER BY "^map.b^","^map.c
     ^ (!! " LIMIT %d OFFSET %d" limit offset))
    [ `Id (ctx # db) ; `Binary (Pack.to_string map.apack a) ] 
  in

  return 
    (List.map
       (fun a -> 
	 Pack.of_string map.bupack (Postgresql.unescape_bytea a.(0)),
	 Pack.of_string map.cupack (Postgresql.unescape_bytea a.(1)))
       (Array.to_list result))

let all2 map ?(limit=1000) ?(offset=0) a b =

  let! ctx = Run.context in 
  let! ()  = Run.with_context (ctx :> ctx) map.wait in 
  let! dbname = Run.with_context (ctx :> ctx) map.dbname in 

  let! result = Sql.query 
    ("SELECT "^map.c^" FROM \""^dbname^"\" "
     ^ "WHERE \"db\" = $1 AND "^map.a^" = $2 AND "^map.b^" = $3 ORDER BY "^map.c
     ^ (!! " LIMIT %d OFFSET %d" limit offset))
    [ `Id (ctx # db) ; `Binary (Pack.to_string map.apack a) ; `Binary (Pack.to_string map.bpack b) ] 
  in

  return 
    (List.map
       (fun a -> Pack.of_string map.cupack (Postgresql.unescape_bytea a.(0)))
       (Array.to_list result))
