(** Returns the full name of a stream. Only call this once for a given 
    stream name. *)
val stream : string -> string

type prefix 

(** Returns a prefix to be used for projections. *)
val projection_prefix : string -> (Common.ctx, int) Run.t -> prefix

(** Returns the full database name for a map. Only call this once for
    a given map name. *)
val view : ?prefix:prefix -> string -> int -> ( Common.ctx, string ) Run.t

(** Same as {!view}, but creates an independent view and does not require
    a database read to generate (because there is no need to query for a 
    projection version). *)
val independent : string -> int -> string

(** Current version identifier, computed based on all the registered names
    so far. *)
val version : unit -> ( Common.ctx, string ) Run.t
