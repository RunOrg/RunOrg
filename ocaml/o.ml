open Ohm

let config = Config.Database.dev

let () = 
  Configure.set `Log "/var/log/ohm/dev.log"

class ctx = object
  inherit Cqrs.cqrs_ctx config
  val time = Time.now () 
  method time = time 
end 

