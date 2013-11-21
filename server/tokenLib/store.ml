(* © 2013 RunOrg *)

module Owner = type module [ `ServerAdmin ]
type owner = Owner.t

(* The token store is an event-independent table, because : 

   - There will be a LOT of token activity, possibly more than any other activity 
     except page views. Storing that in a stream will hurt in terms of migration 
     time.
   - We need instant reaction times when creating a new token. *)

let dbname = Cqrs.Names.independent "tokens" 1 

let () = Cqrs.Sql.on_first_connection (Cqrs.Sql.command begin 
  "CREATE TABLE IF NOT EXISTS \"" ^ dbname ^ "\" ( "
  ^ "\"token\" CHAR(40) NOT NULL, "
  ^ "\"payload\" BYTEA NOT NULL, "
  ^ "\"created\" TIMESTAMP NOT NULL DEFAULT('now'), "
  ^ "PRIMARY KEY(\"token\"))"
end [])



let create owner = assert false
let is_server_admin id = assert false

