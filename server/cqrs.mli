(** A database connection. This is an internal type that you should not use. *)
type cqrs

(** Configuration object for connecting to a PostgreSQL database. *)
type config = {
  host : string ;
  port : int ;
  database : string ;
  user : string ;
  password : string 
}

(** Exception raised when connecting to the database failed. *)
exception ConnectionFailed of string

(** A database context: all operations related to CQRS should be executed
    while in this context. *)
class type ctx = object
  method cqrs : cqrs
  method time : Time.t 
end 

(** A concrete implementation of the [cqrs] part of [ctx]. *)
class virtual cqrs_ctx : config -> object 
  method cqrs : cqrs
  method virtual time : Time.t
end

(** An event writer is a function that writes events of the specified type to 
    an underlying stream. *)
type ('ctx, 'a) event_writer = 'a list -> ( 'ctx , unit ) Run.t

module Clock : sig

  include Fmt.FMT

  (** An empty vector clock : does not track any streams. *)
  val empty : t

  (** Merge two clocks. If a stream is referenced by both clocks, the
      highest revision number if kept. *)
  val merge : t -> t -> t 

  (** Are all the streams in the first clock at an earlier revision 
      number than those in the second clock ? If the second clock does not
      contain a revision for a stream, assume that it is later. *)
  val earlier_than_constraint : t -> t -> bool 

  (** As [earlier_than_constraint], but streams missing from the
      second clock are assumed to be at revision -1. *)
  val earlier_than_checkpoint : t -> t -> bool
    
end

module Names : sig

  (** A name prefix, used by projection-dependent structures to create tables in the
      database. *)
  type prefix 

end

(** Each projection has a name and version number. Several projections 
    with the same name but different version numbers may exist in the database.
    
    Once the projection with the latest version number has caught up 
    with all its underlying streams, the previous version numbers may be 
    deleted to save space. 
    
    Inside the database, tables involved in the projection will be prefixed with 
    'proj:{thename}:{theversion}' 
*)
module Projection : sig 

  (** An individual projection *)
  type t

  (** A view, following a projection. *)
  type view

  (** Create a projection from a name and a projection function. *)
  val make : string -> (unit -> ctx) -> t

  (** [register kind name version] registers an view of type [kind] called
      [name] at version number [version]. 

      This is used to automatically 
      increment the projection version number based on its contents. *)
  val view : t -> string -> string -> int -> view
    
  (** The name of a projection. *)
  val name : t -> string

  (** The current clock of this projection. *)
  val clock : t -> (#ctx, Clock.t) Run.t

  (** Runs all registered projections in parallel, until a reset is requested
      using [Cqrs.Running.reset ()] from another process. *)
  val run : unit -> unit Run.thread 

  (** The prefix of a view, used to create the corresponding tables in the 
      database. *)
  val prefix : view -> Names.prefix

  (** The projection from which a view was created. *)
  val of_view : view -> t

end

(** A stream is a persistent sequence of events.  *)
module type STREAM = sig

  (** The type of events stored in this stream. *)
  type event

  (** The name of the stream. Will be called 'stream:{thename}' in the database. *)
  val name : string

  (** Appends one or more events to the event stream. *)
  val append : ( #ctx, event ) event_writer

  (** The number of events in this stream. *)
  val count : unit -> ( #ctx, int ) Run.t

  (** The current clock for this stream. *)
  val clock : unit -> ( #ctx, Clock.t ) Run.t

  (** Have a view track events from this stream, running an effect for every
      one of them. *)
  val track : Projection.view -> (event -> ctx Run.effect) -> unit
    
end

(** Creates a new stream with the specified name and (packable) event type. *)
module Stream : functor(Event:sig 
  include Fmt.FMT 
  val name : string 
end) -> STREAM with type event = Event.t

(** Maps bind values to keys. *)

module MapView : sig

  (** A persistent map *)

  type ('key, 'value) t 

  (** Create a map from a key type and a value type. Both types must support 
      packing. A map always has a name, and is placed inside a projection. *)
  val make : Projection.t -> string -> int -> 
    (module Fmt.FMT with type t = 'key) ->
    (module Fmt.FMT with type t = 'value) ->
    Projection.view * ('key, 'value) t

  (** A standalone map, outside of a projection. Take care when manipulating, 
      as there is no possibility of replaying an event stream if things go
      wrong. *)
  val standalone : string -> int -> 
    (module Fmt.FMT with type t = 'key) ->
    (module Fmt.FMT with type t = 'value) ->
    ('key, 'value) t

  (** Update a map. *) 
  val update : ('key, 'value) t -> 'key -> 
    ('value option -> [ `Keep | `Put of 'value | `Delete ]) -> 
    # ctx Run.effect

  (** Update a map, with a monad update function.. *) 
  val mupdate : ('key, 'value) t -> 'key -> 
    ('value option -> (# ctx as 'ctx, [ `Keep | `Put of 'value | `Delete ]) Run.t) -> 
    'ctx Run.effect

  (** Grab a value from a map. *)
  val get : ('key, 'value) t -> 'key -> (# ctx, 'value option) Run.t

end

(** Keeping track of running instances. *)
module Running : sig

  (** Thrown when a shutdown is requested. *)
  exception Shutdown 

  (** Ask for all instances to shut down. *)
  val reset : #ctx -> unit

  (** Long-running thread, marks the instance as still
      running. Throws [Shutdown] (and breaks out of eval) when 
      a shutdown is requested. *)
  val heartbeat : #ctx -> unit Run.thread

end

(** Module for running SQL queries directly. *)
module Sql : sig

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

  val query : string -> param list -> ( #ctx, raw_result ) Run.t 

  (** A command is like a query, but returns no results, and will
      block if a transaction is active (until the transaction ends). *)

  val safe_command : string -> param list -> #ctx Run.effect

  (** Like [safe_command] but does not block when part of a transaction. *)

  val command : string -> param list -> #ctx Run.effect

  (** Runs specific code on the first connection. *)

  val on_first_connection : ctx Run.effect -> unit

  (** Executes an operation inside a transaction *)

  val transaction : (#ctx as 'ctx, 'a) Run.t -> ( 'ctx, 'a ) Run.t

end
