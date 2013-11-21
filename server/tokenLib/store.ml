(* © 2013 RunOrg *)

type owner = [ `ServerAdmin ]

(* The token store is an event-independent table, because : 

   - There will be a LOT of token activity, possibly more than any other activity 
     except page views. Storing that in a stream will hurt in terms of migration 
     time.
   - We need instant reaction times when creating a new token. *)

let dbname = Cqrs.Names.independent "tokens" 1 

let create owner = assert false
let is_server_admin id = assert false

