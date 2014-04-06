(* © 2014 RunOrg *)

(** Is request logging enabled ? *)
val enabled : bool 

(** The type of a request logger. Incorporated within the context. *)
type t 

(** The type of a logger-enabled context. *)
class type ctx = object 
  method logreq : t 
end

(** Start logging a new request, with a timer. *)
val start : (ctx, 'b) Run.t -> (unit, 'b) Run.t

(** Set the source IP of the current request. *)
val set_request_ip : string -> # ctx Run.effect

(** Set the path of the current request. *)
val set_request_path : string -> # ctx Run.effect

(** Log a trace-level piece of information, output to [{date}/trace.log]. If request 
    logging is disabled, nothing happens. *)
val tracef : ( 'a , Format.formatter, unit , # ctx Run.effect ) format4 -> 'a

(** Log a trace-level piece of information, output to [{date}/trace.log]. If request 
    logging is disabled, nothing happens. *)
val trace : string -> # ctx Run.effect
