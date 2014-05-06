(* © 2014 RunOrg *)

(** Wraps a PostgreSQL connection in an object that tracks its state more cleanly
    and exposes a better interface. *)

(** Database configuration. Required to connect to the database. *)
type config = {
  host : string ;
  port : int ;
  database : string ;
  user : string ;
  password : string ;
  pool_size : int ;
}

(** An active, persistent database connection. *)
type t 

(** Connect to the database. 
    @raise CriticalDatabaseError if it could not connect to the database. *)
val connect : config -> t

(** Is this the first time this process has connected to this database ? 
    Provided to allow initialization operations to run. *)
val is_first_connection : t -> bool

(** A query string. *)
type query = string

(** A query parameter. *)
type param = 
  [ `Binary of string 
  | `String of string 
  | `Id of Id.t
  | `Int of int ] 

(** A query result. *)
type result = string array array 

(** Perform a query and return the result asynchronously. 

    If the query fails for any reason, the system will disconnect, 
    reconnect and attempt to perform the query again. 

    If the query fails again, an error will be logged and the process
    will be shut down forcibly. 
*)
val execute : t -> query -> param list -> ('ctx, result) Run.t

(** Marks this connection as 'never be used again'. This module will either 
    close it or return it to the connection pool. 

    If there are still pending operations on the database, the system will
    politely wait for 30 seconds for them to finish, then issue a fatal 
    error if they are still not done. 
*)
val release : t -> ('ctx,unit) Run.t

(** Begin a new transaction. *)
val transaction : t -> ('ctx,unit) Run.t

(** Commit the current transaction. *)
val commit : t -> ('ctx,unit) Run.t
