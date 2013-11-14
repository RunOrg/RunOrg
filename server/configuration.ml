type role = [ `Bot | `Web | `Reset ]

let role =
  if Array.length Sys.argv < 2 then `Web
  else if Sys.argv.(1) = "bot" then `Bot
  else if Sys.argv.(1) = "reset" then `Reset
  else `Web
    
let log_prefix = "/var/log/runorg"

module Database = struct
  let host = "localhost" 
  let port = 5432 
  let database = "dev" 
  let user = "dev" 
  let password = "dev" 
end
