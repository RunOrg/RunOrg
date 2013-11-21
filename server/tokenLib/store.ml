(* © 2013 RunOrg *)

open Std

module Owner = type module [ `ServerAdmin ]
type owner = Owner.t

(* The token store is an event-independent table, because : 

   - There will be a LOT of token activity, possibly more than any other activity 
     except page views. Storing that in a stream will hurt in terms of migration 
     time.
   - We need instant reaction times when creating a new token. *)

let dbname = Cqrs.Names.independent "tokens" 1 

let () = 
  Cqrs.Sql.on_first_connection (Cqrs.Sql.command begin 
    "CREATE TABLE IF NOT EXISTS \"" ^ dbname ^ "\" ( "
    ^ "\"token\" CHAR(40) NOT NULL, "
    ^ "\"payload\" BYTEA NOT NULL, "
    ^ "\"created\" TIMESTAMP NOT NULL DEFAULT('now'), "
    ^ "PRIMARY KEY(\"token\"))"
  end []) ;

  (* 2 days is longer than the actual session life : this is a cleanup function, 
     not an invalidation function. Invalidation happens when loading data. *)
  Cqrs.Sql.on_first_connection (Cqrs.Sql.command begin 
    "DELETE FROM \"" ^ dbname ^ "\" WHERE \"created\" < 'now' - interval '2 days'"
  end [])

(* Creating new sessions 
   ===================== *)

let create owner =
  let  id = I.gen () in
  let! () = Cqrs.Sql.command ("INSERT INTO \"" ^ dbname ^ "\" (\"token\", \"payload\") VALUES ($1, $2)")
    [ `String (I.to_string id) ; `Binary (Pack.to_string Owner.pack owner) ] in
  return id 

(* Loading old sessions
   ==================== *)

let session_life = "interval '1 hour'"

let load id = 
  let! result = Cqrs.Sql.query begin 
    "SELECT \"payload\" FROM \"" ^ dbname ^ "\" "
    ^ "WHERE \"token\" = $1 AND \"created\" < 'now' - " ^ session_life
  end [ `String (Id.to_string id) ] in
  return (Cqrs.Result.unpack result Owner.unpack)

let is_server_admin id = assert false

