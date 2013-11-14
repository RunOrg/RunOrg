type role = [ `Bot | `Web | `Reset ]

let role =
  if BatArray.mem "bot" Sys.argv then `Bot 
  else if BatArray.mem "reset" Sys.argv then `Reset 
  else `Web

let to_stdout = 
  BatArray.mem "-stdout" Sys.argv
    
let log_prefix = if to_stdout then None else Some "/var/log/runorg"

module Database = struct
  let host = "localhost" 
  let port = 5432 
  let database = "dev" 
  let user = "dev" 
  let password = "dev" 
end
