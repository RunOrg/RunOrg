type role = [ `Bot | `Web | `Reset ]

let role =
  let bot     = ref false 
  and reset   = ref false in 
  Arg.parse [
    "reset", Arg.Set reset, "force other processes to restart" ;
    "bot",   Arg.Set bot,   "run as bot" ;
  ] (fun _ -> ()) "Start an instance of the Ohm server" ;
  if !bot then `Bot else 
    if !reset then `Reset else `Web
    
let log_prefix = "/var/log/runorg"

module Database = struct
  let host = "localhost" 
  let port = 5432 
  let database = "dev" 
  let user = "dev" 
  let password = "dev" 
end
