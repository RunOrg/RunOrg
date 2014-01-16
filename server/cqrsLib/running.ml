open Common

(* Starting a new run 
   ================== *)

let start () = 

  let start () = 
    
    let! hash = Run.edit_context (fun ctx -> (ctx :> ctx)) (Names.version ()) in 
    let pid = Unix.getpid () in
    let host = 
      let addrs = (Unix.gethostbyname (Unix.gethostname ())).Unix.h_addr_list in
      if Array.length addrs > 0 then Unix.string_of_inet_addr addrs.(0) else ""
    in

    let! result = Sql.query begin
      "INSERT INTO \"meta:runs\" (\"version\", \"hash\", \"host\", \"pid\", \"started\", \"heartbeat\") " 
      ^ "VALUES ($1, $2, $3, $4, 'now', 'now') " 
      ^ "RETURNING \"id\""
    end [ `String RunorgVersion.version_string ; `String hash ; `String host ; `Int pid ] in 

    Run.return (Some (int_of_string (result.(0).(0))))

  in

  match Configuration.role with
  | `Run -> start ()
  |  _   -> Run.return None

(* Asking for a global shutdown
   ============================ *)

let reset ctx =
  Run.eval ctx 
    (Sql.command "UPDATE \"meta:runs\" SET \"shutdown\" = 'now' WHERE \"shutdown\" IS NULL" []) 
	
(* Stay alive 
   ========== *)

exception Shutdown
	      
let heartbeat ctx =
  Run.with_context ctx begin
    let! id = start () in
    match id with None -> raise Shutdown | Some id ->
      Run.loop begin fun continue -> 
	
	let! () = Run.sleep 10000.0 in

	let! result = Sql.query begin
	  "UPDATE \"meta:runs\" SET \"heartbeat\" = 'now' WHERE \"id\" = $1 "
	  ^ "RETURNING \"shutdown\" IS NOT NULL"
	end [ `Int id ] in
	
	let alive = result.(0).(0) = "f" in 
	
	if alive then continue else raise Shutdown

      end	  
  end

(* Defining the runs table 
   ======================= *)

let () = 

  Sql.on_first_connection (Sql.command begin
    "CREATE TABLE IF NOT EXISTS \"meta:runs\" ( "
    ^ "\"id\" SERIAL, "
    ^ "\"version\" VARCHAR(10) NOT NULL, "
    ^ "\"hash\" CHAR(40) NOT NULL, "
    ^ "\"host\" VARCHAR(100) NOT NULL, "
    ^ "\"pid\" INTEGER NOT NULL, "
    ^ "\"started\" TIMESTAMP NOT NULL, "
    ^ "\"heartbeat\" TIMESTAMP NOT NULL, "
    ^ "\"shutdown\" TIMESTAMP NULL, "
    ^ "PRIMARY KEY (\"id\")"
    ^ ")"
  end [])

