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

let admins = [ "vnicollet@runorg.com" ]

module Httpd = struct
  let port = 4443 
  let key_path = "key.pem" 
  let certificate_path = "cert.pem" 
  let key_password = "test"
  let max_header_size = 4096
  let max_body_size = min Sys.max_string_length (1024*1024)
end
