(* © 2013 RunOrg *)

(** The type of parameters to raw queries. *)
type param = [ `Binary of string
	     | `String of string 
	     | `Int of int ] 

(** The type of raw results. *)
type raw_result = string array array

(** Runs a query asynchronously. Queries are sequential (that is, 
    they are executed in the order they are provided in), but the
    asynchronous interface lets the program perform other operations
    while queries are running. *)

val query : string -> param list -> ( #Common.ctx, raw_result ) Run.t 

(** A safe query is like a query, but will block if a transaction is 
    active (until the transaction ends).  *)

val safe_query : string -> param list -> ( #Common.ctx, raw_result ) Run.t

(** A command is like a query, but does not results *)

val command : string -> param list -> #Common.ctx Run.effect

(** Runs specific code on the first connection. *)

val on_first_connection : Common.ctx Run.effect -> unit

(** Executes an operation inside a transaction *)

val transaction : (#Common.ctx as 'ctx, 'a) Run.t -> ( 'ctx, 'a ) Run.t

 
