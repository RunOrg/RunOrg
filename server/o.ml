let config = Cqrs.(Configuration.Database.({ host ; port ; user ; database ; password }))

class ctx = object
  inherit Cqrs.cqrs_ctx config
  val time = Time.now () 
  method time = time 
end 

