(* © 2013 RunOrg *)

(** A multiplexed HTTP server implementation. *)

type request
type response

type 'ctx handler = request -> response -> ('ctx, response) Run.t

type config = { port: int ; certificate : string }

val start : config -> 'ctx handler -> 'ctx Run.thread

