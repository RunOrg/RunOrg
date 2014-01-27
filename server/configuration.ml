type role = [ `Run | `Reset ]

let test = true

let role =
  if BatArray.mem "reset" Sys.argv then `Reset else `Run

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

let admin_audience = "https://runorg.local:4443"

module Httpd = struct
  let port = 4443 
  let key_path = "key.pem" 
  let certificate_path = "cert.pem" 
  let key_password = "test"
  let max_header_size = 4096
  let max_body_size = min Sys.max_string_length (1024*1024)
  let max_duration = 1.0
end

let token_key = "6>0R@>VTlhnVSUZ`9&&'S918VpKPtO"
