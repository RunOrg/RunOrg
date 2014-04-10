(* © 2014 RunOrg *)

let config = Cqrs.(Configuration.Database.({ host ; port ; user ; database ; password ; pool_size }))

let cqrs cqrs = new Cqrs.cqrs_ctx cqrs

class ctx (cqrs : Cqrs.cqrs) (logctx : LogReq.ctx) = object

  inherit Cqrs.cqrs_ctx cqrs

  val logreq = logctx # logreq
  method logreq = logreq

end 

