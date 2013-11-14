let config = Config.Database.dev

class ctx = object
  inherit Cqrs.cqrs_ctx config
  val time = Time.now () 
  method time = time 
end 

