type cqrs

type config = {
  host : string ;
  port : int ;
  database : string ;
  user : string ;
  password : string 
}

exception ConnectionFailed of string

class type ctx = object
  method cqrs : cqrs
  method time : Time.t 
end 

class virtual cqrs_ctx : config -> object 
  method cqrs : cqrs
  method virtual time : Time.t
end

type result = string array array

type param = [ `Binary of string
	     | `String of string 
	     | `Int of int ] 

(** Runs a query asynchronously. Queries are sequential (that is, 
    they are executed in the order they are provided in), but the
    asynchronous interface lets the program perform other operations
    while queries are running. *)

val query : string -> param list -> ( #ctx, result ) Run.t 

(** A command is like a query, but returns no results, and will
    block if a transaction is active (until the transaction ends). *)

val safe_command : string -> param list -> ( #ctx, unit ) Run.t 

(** Like [safe_command] but does not block when part of a transaction. *)

val command : string -> param list -> ( #ctx, unit ) Run.t 

(** Runs a specific query on the first connection. *)

val query_on_first_connection : string -> param list -> unit

(** Runs specific code on the first connection. *)

val run_on_first_connection : ( ctx, unit) Run.t -> unit

(** Executes an operation inside a transaction *)

val transaction : (#ctx as 'ctx, 'a) Run.t -> ( 'ctx, 'a ) Run.t

