(* © 2013 RunOrg *)

(** A multiplexed HTTP server implementation. *)

type request

type response

type 'ctx handler = request -> response -> ('ctx, response) Run.t

type config = { 
  port: int ; 
  key_path : string ; 
  key_password : string ; 
  certificate_path : string ; 
  max_header_size : int ;
  max_body_size : int ; 
}

val start : config -> 'ctx handler -> 'ctx Run.thread

