(* © 2014 RunOrg *)

(** The type of a request handler. *)
type 'ctx handler = Request.t -> ('ctx, Response.t) Run.t

(** Start the server. Return a thread that executes all requests 
    received by the server. *)
val start : Common.config -> LogReq.ctx handler -> unit Run.thread
