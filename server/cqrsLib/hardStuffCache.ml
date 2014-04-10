(* © 2014 RunOrg *)

open Std
open Common

type ('key,'value) t = {
  kpack : 'key Pack.packer ;
  vpack : 'value Pack.packer ;
  vupack : 'value Pack.unpacker ;
  name : string ; 
  dbname : string ;
  run : 'key -> (ctx,'value) Run.t ;
  mutable mutexes : ('key,Run.mutex) Map.t ;
}

(* Creating a new cache
   ==================== *)

let make (type k) (type v) name version key value run = 

  let module Key = (val key : Fmt.FMT with type t = k) in
  let module Value = (val value : Fmt.FMT with type t = v) in

  let dbname = "cache:" ^ name ^ ":" ^ string_of_int version in
  
  let () = Sql.on_first_connection begin
    Sql.command ("CREATE TABLE IF NOT EXISTS \"" ^ dbname ^ "\" ( " 
		 ^ "\"db\" CHAR(11), "
		 ^ "\"key\" BYTEA, "
		 ^ "\"clock\" BYTEA, "
		 ^ "\"value\" BYTEA, "
		 ^ "PRIMARY KEY (\"db\",\"key\") "
		 ^ ");") []
  end in
  
  { name ; dbname ; run ; kpack = Key.pack ; vpack = Value.pack ; vupack = Value.unpack ;
    mutexes = Map.empty }

(* Cache manipulation helpers
   ========================== *)

let get_current t db kP = 

  let! result = Sql.query 
    ("SELECT \"clock\", \"value\" FROM \"" ^ t.dbname ^ "\" WHERE \"db\" = $1 AND \"key\" = $2")
    [ `Id db ; `Binary kP ] in
  
  if Array.length result = 0 then return None else
    return (Some (Pack.of_string Clock.unpack (Postgresql.unescape_bytea result.(0).(0)),
		  lazy (Pack.of_string t.vupack (Postgresql.unescape_bytea result.(0).(1)))))

let get_clock t db kP = 

  let! result = Sql.query 
    ("SELECT \"clock\" FROM \"" ^ t.dbname ^ "\" WHERE \"db\" = $1 AND \"key\" = $2")
    [ `Id db ; `Binary kP ] in
  
  if Array.length result = 0 then return None else
    return (Some (Pack.of_string Clock.unpack (Postgresql.unescape_bytea result.(0).(0))))

let insert t db kP clock value = 

  let cP = Pack.to_string Clock.pack clock in
  let vP = Pack.to_string t.vpack value in 

  Sql.command 
    ("UPDATE \"" ^ t.dbname ^ "\" SET \"clock\" = $1 AND \"value\" = $2 WHERE"
     ^ " \"db\" = $3 AND \"key\" = $4")
    [ `Binary cP ; `Binary vP ; `Id db ; `Binary kP ]

let update t db kP clock value = 

  let cP = Pack.to_string Clock.pack clock in
  let vP = Pack.to_string t.vpack value in 

  Sql.command 
    ("INSERT INTO \"" ^ t.dbname ^ "\" (\"db\",\"key\",\"clock\",\"value\") VALUES"
     ^ " ($1,$2,$3,$4)")
    [ `Id db ; `Binary kP ; `Binary cP ; `Binary vP ]

let get t k clock = 

  (* Wrap the operation in a mutex. Clean up the mutex afterwards. *)
  
  let mutex = try Map.find k t.mutexes with Not_found -> 
    let mutex = new Run.mutex in 
    t.mutexes <- Map.add k mutex t.mutexes ; mutex in

  let! ctx = Run.context in
  let  db  = ctx # db in
  let  kP  = Pack.to_string t.kpack k in

  let! value = mutex # lock begin

    let! current = get_current t db kP in
    match current with 
    | Some (clock', value) when Clock.earlier_than_checkpoint clock clock' -> return (Lazy.force value) 
    | _ -> 
  
      (* This call may take a while. *)
      let! value = Run.edit_context (fun ctx -> (ctx :> ctx)) (t.run k) in

      (* If this value is the latest one, save it to the database. *)
      let! () = Sql.transaction begin 

	let! updated = get_clock t db kP in

	match updated with 
	| Some clock' when Clock.earlier_than_checkpoint clock' clock -> update t db kP clock value
	| None -> insert t db kP clock value
	| _ -> return ()

      end in

      return value

  end in
  
  let () = if not (mutex # locked) then t.mutexes <- Map.remove k t.mutexes in
  
  return value
