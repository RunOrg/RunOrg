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
  wait : (ctx, unit) Run.t ;
  dbname : (ctx, string) Run.t
}

type ('id,'value) node = <
  time    : Time.t ;
  id      : 'id ;
  count   : int ;
  value   : 'value ;
  subtree : ('id, 'value) node list 
>

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
		 ^ "\"p\" BYTEA, " 
		 ^ "\"value\" BYTEA, "
		 ^ "\"t\" CHAR(14), "
		 ^ "\"count\" INT, "
		 ^ "PRIMARY KEY (\"db\",\"key\",\"id\") "
		 ^ ");") []
  end in 

  let wait = Projection.wait projection in 
  
  view, { name ; dbname ; wait ;
    kpack = Key.pack ; kupack = Key.unpack ;
    ipack = Id.pack ; iupack = Id.unpack ;
    vpack = Value.pack ; vupack = Value.unpack }

(* Reading an item from the map
   ========================= *)

let full_get map k i = 

  let  k = Pack.to_string map.kpack k in 
  let  i = Pack.to_string map.ipack i in 
  
  let! ctx = Run.context in 
  let! ()  = Run.with_context (ctx :> ctx) map.wait in 
  let! dbname = Run.with_context (ctx :> ctx) map.dbname in 
  let! result = Sql.query 
    ("SELECT \"t\", \"value\", \"p\", \"count\" FROM \"" 
     ^ dbname 
     ^ "\" WHERE \"db\" = $1 AND \"key\" = $2 AND \"id\" = $3")
    [ `Id (ctx # db) ; `Binary k ; `Binary i ]
  in

  let found = if Array.length result = 0 then None else
      let parent = Postgresql.unescape_bytea result.(0).(2) in
      let value  = Pack.of_string map.vupack (Postgresql.unescape_bytea result.(0).(1)) in
      let count  = int_of_string result.(0).(3) in
      match Time.of_compact result.(0).(0) with None -> None | Some time -> 
	Some (time, parent, count, value)
  in
  
  Run.return (k, i, ctx # db, dbname, found)

let get map k i = 
  let! _, _, _, _, r = full_get map k i in 
  return (match r with None -> None | Some (t, _, c, v) -> Some (object
    method time    = t 
    method id      = i
    method count   = c
    method value   = v
    method subtree = []
  end))

let exists map k i = 
  
  let  k = Pack.to_string map.kpack k in 
  let  i = Pack.to_string map.ipack i in 
  
  let! ctx = Run.context in 
  let! ()  = Run.with_context (ctx :> ctx) map.wait in 
  let! dbname = Run.with_context (ctx :> ctx) map.dbname in 
  let! result = Sql.query 
    ("SELECT 1 FROM \"" ^ dbname ^ "\" WHERE \"db\" = $1 AND \"key\" = $2 AND \"id\" = $3")
    [ `Id (ctx # db) ; `Binary k ; `Binary i ]
  in

  return (Array.length result > 0)

(* Updating the map contents 
   ========================= *)

let recount map db dbname k i =
  if i = "" then return () else 
    Sql.command 
      ("UPDATE \"" ^ dbname ^ "\" SET \"count\" = sub.c " 
       ^ "FROM (SELECT COUNT(*) AS c FROM \"" ^ dbname ^ "\""
       ^ "  WHERE \"db\" = $1 AND \"key\" = $2 AND \"p\" = $3) sub "
       ^ "WHERE \"db\" = $1 AND \"key\" = $2 AND \"id\" = $3 AND sub.c <> \"count\"")
      [ `Id db ; `Binary k ; `Binary i ]

let rec delete_children map db dbname k list = 
  
  let n = List.length list in
  if n = 0 then return () else 

    let args = `Id db :: `Binary k :: List.map (fun i -> `Binary i) list in
    
    let! result = Sql.query
      ("SELECT \"id\" FROM \"" ^ dbname ^ "\" WHERE \"p\" IN ("
       ^ (String.concat "," List.(map (fun i -> "$" ^ string_of_int (i + 3)) (0 -- n)))
       ^ ") AND \"count\" > 0 AND \"db\" = $1 AND \"key\" = $2")
      args in 
    
    let children = List.map (fun a -> Postgresql.unescape_bytea a.(0)) (Array.to_list result) in
    
    let! () = Sql.command
      ("DELETE FROM \"" ^ dbname ^ "\" WHERE \"p\" IN ("
       ^ (String.concat "," List.(map (fun i -> "$" ^ string_of_int (i + 3)) (0 -- n)))
       ^ ") AND \"db\" = $1 AND \"key\" = $2")
      args in 

    delete_children map db dbname k children 

let mupdate map k i f = 
  
  let! k, i, db, dbname, found = full_get map k i in 

  let oldp = match found with Some (_,p,_,_) -> p | None -> "" in

  let! r = f (match found with 
    | None -> None
    | Some (a,"",_,b) -> Some (a,None,b)
    | Some (a,p,_,b) -> Some (a,Some (Pack.of_string map.iupack p),b)) in 

  match r with 
  | `Keep -> return () 
  | `Delete ->
 
    let! () = delete_children map db dbname k [ i ] in 

    let! () = Sql.command 
      ("DELETE FROM \"" ^ dbname ^ "\" WHERE \"db\" = $1 AND \"key\" = $2 AND \"id\" = $3")
      [ `Id db ; `Binary k ; `Binary i ] in

    recount map db dbname k oldp

  | `Put (t, p, v) -> 
    let v = Pack.to_string map.vpack v in 
    let p = match p with None -> "" | Some p -> Pack.to_string map.ipack p in
    let t = Time.to_compact t in 
    if found = None then 

      let! () = Sql.command
	("INSERT INTO \"" ^ dbname ^ "\" (\"db\",\"key\",\"id\",\"t\",\"value\",\"p\",\"count\") "
	 ^ "VALUES ($1,$2,$3,$4,$5,$6,0)")
	[ `Id db ; `Binary k ; `Binary i ; `String t ; `Binary v ; `Binary p ] in
      
      recount map db dbname k p

    else 

      let! () = Sql.command
	("UPDATE \"" ^ dbname ^ "\" SET \"t\" = $4, \"value\" = $5, \"p\" = $6 "
	 ^ "WHERE \"db\" = $1 AND \"key\" = $2 AND \"id\" = $3")
	[ `Id db ; `Binary k ; `Binary i ; `String t ; `Binary v ; `Binary p ] in
      
      if oldp = p then return () else 
	let! () = recount map db dbname k p in
	recount map db dbname k oldp 

let update map k i f = mupdate map k i (fun v -> return (f v))

(* Deleting a feed 
   =============== *)

let delete map k = 

  let  k = Pack.to_string map.kpack k in 
  
  let! ctx = Run.context in 
  let! dbname = Run.with_context (ctx :> ctx) map.dbname in 

  Sql.command
    ("DELETE FROM \"" ^ dbname ^ "\"WHERE \"db\" = $1 AND \"key\" = $2")
    [ `Id (ctx # db) ; `Binary k ]
  
(* Gathering stats for a key. 
   ========================== *)

let stats map k = 

  let  k = Pack.to_string map.kpack k in 
  
  let! ctx = Run.context in 
  let! ()  = Run.with_context (ctx :> ctx) map.wait in 
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

  let! result = Sql.query 
    ("SELECT COUNT(*) FROM \"" ^ dbname ^ "\" WHERE \"db\" = $1 AND \"key\" = $2 AND \"p\" = $3")
    [ `Id (ctx # db) ; `Binary k ; `Binary "" ]
  in
  
  let root = int_of_string result.(0).(0) in

  return (object
    method count = count
    method root  = root
    method first = first
    method last  = last 
  end)

(* Extracting feed values 
   ====================== *)

let list_children map db dbname k limit offset list = 
  
  let n = List.length list in 
  if n = 0 then return [] else
    
    let args = `Id db :: `Binary k :: List.map (fun i -> `Binary i) list in 
    
    let! result = Sql.query 
      ("SELECT \"id\", \"p\", \"t\", \"count\", \"value\" FROM \"" ^ dbname ^ "\" "
       ^ "WHERE \"db\" = $1 AND \"key\" = $2 AND \"p\" IN ("
       ^ (String.concat "," List.(map (fun i -> "$" ^ string_of_int (i + 3)) (0 -- n)))
       ^ ") ORDER BY \"t\" DESC "
       ^ (!! "LIMIT %d OFFSET %d" limit offset))
      args in
      
    return (List.filter_map (fun a -> 

      let id = Postgresql.unescape_bytea a.(0) in
      let p  = match Postgresql.unescape_bytea a.(1) with "" -> None | pack -> Some pack in
      let t  = Time.of_compact a.(2) in
      let c  = int_of_string a.(3) in
      let v  = Pack.of_string map.vupack (Postgresql.unescape_bytea a.(4)) in

      match t with None -> None | Some t -> 
	Some (id, p, t, c, v)

    ) (Array.to_list result))

let rec recurse_to_depth map db dbname k limit offset depth acc list = 
  
  if depth < 0 || list = [] then return acc else

    let! children = list_children map db dbname k limit offset list in 
    let  list = List.filter_map (fun (id, _, _, c, _) -> if c = 0 then None else Some id) children in 
    let  acc  = List.fold_left (fun acc item -> 
      let (_, p, _, _, _) = item in 
      let l = try Map.find p acc with Not_found -> [] in
      Map.add p (item :: l) acc) acc children in 

    recurse_to_depth map db dbname k limit 0 (depth - 1) acc list

let rec build map byParent i = 
  
  let list = try Map.find i byParent with Not_found -> [] in
  List.rev_map (fun (id, _, t, c, v) -> (object
    method time = t
    method count = c
    method id = Pack.of_string map.iupack id
    method value = v
    method subtree = build map byParent (Some id) 
  end : ('a,'b) node)) list 

let list map ?(depth=0) ?(limit=1000) ?(offset=0) ?parent k = 

  let  k = Pack.to_string map.kpack k in 
  let  p = match parent with None -> None | Some p -> Some (Pack.to_string map.ipack p) in
  
  let! ctx = Run.context in 
  let  db  = ctx # db in 
  let! ()  = Run.with_context (ctx :> ctx) map.wait in 
  let! dbname = Run.with_context (ctx :> ctx) map.dbname in 

  let! byParent = recurse_to_depth map db dbname k limit offset depth Map.empty
    [match p with None -> "" | Some p -> p] in

  return (build map byParent p) 

(* Extracting chronological values
   =============================== *)
    
let ticker ?(limit=1000) ?since map = 

  let! ctx = Run.context in 
  let! ()  = Run.with_context (ctx :> ctx) map.wait in 
  let! dbname = Run.with_context (ctx :> ctx) map.dbname in 

  (* Find out the time value based on the (key,id) pair, directly build the serialized 
     set of arguments. *)

  let! since = match since with None -> return None | Some (key,id) ->

    let  args = [ `Id (ctx # db) ;
		  `Binary (Pack.to_string map.kpack key) ;
		  `Binary (Pack.to_string map.ipack id) ] in

    let! result = Sql.query 
      ("SELECT \"t\" FROM \""^dbname^"\" WHERE \"db\" = $1 AND \"id\" = $2") 
      args in
    
    return (if Array.length result = 0 then None else Some (args @ [ `String result.(0).(0) ]))
  
  in

  (* The actual query. *)

  let query = 
    "SELECT \"key\", \"id\", \"t\" FROM \"" ^ dbname ^ "\" WHERE \"db\" = $1" 
    ^ (if since = None then "" else " AND ROW(\"t\",\"id\",\"key\") > ROW($4,$3,$2)") 
    ^ "ORDER BY \"t\", \"id\", \"key\" LIMIT " ^ string_of_int limit 
  in

  let args = match since with None -> [ `Id (ctx # db) ] | Some sort -> sort in

  let! result = Sql.query query args in

  return 
    (List.map 
       (fun a -> 
	 Pack.of_string map.kupack (Postgresql.unescape_bytea a.(0)),
	 Pack.of_string map.iupack (Postgresql.unescape_bytea a.(1)),
	 Option.default (ctx # time) (Time.of_compact a.(2)))
       (Array.to_list result))
