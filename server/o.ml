(* © 2014 RunOrg *)

let config = Cqrs.(Configuration.Database.({ host ; port ; user ; database ; password }))

let cqrs () = new Cqrs.cqrs_ctx config

class ctx (logctx : LogReq.ctx) = object

  inherit Cqrs.cqrs_ctx config

  val logreq = logctx # logreq
  method logreq = logreq

end 

