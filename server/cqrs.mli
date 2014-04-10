(** A database connection. This is an internal type that you should not use. *)
type cqrs

(** Configuration object for connecting to a PostgreSQL database. *)
type config = {
  host : string ;
  port : int ;
  database : string ;
  user : string ;
  password : string ;
  pool_size : int ;
}

(** Exception raised when connecting to the database failed. *)
exception ConnectionFailed of string

module Clock : sig

  include Fmt.FMT

  (** An empty vector clock : does not track any streams. *)
  val empty : t

  (** Is a vector clock empty (void of constraints) ? *)
  val is_empty : t -> bool

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

(** A database context: all operations related to CQRS should be executed
    while in this context. By default, executes in the 'global' database
    (id 00000000000). *)
class type ctx = object ('self) 
  method cqrs : cqrs
  method time : Time.t 
  method with_time : Time.t -> 'self
  method db   : Id.t
  method with_db : Id.t -> 'self 
  method after : Clock.t
  method with_after : Clock.t -> 'self
end 

(** A concrete implementation of the [cqrs] part of [ctx]. *)
class cqrs_ctx : cqrs -> object ('self) 
  method cqrs : cqrs
  method time : Time.t
  method with_time : Time.t -> 'self 
  method db : Id.t 
  method with_db : Id.t -> 'self
  method after : Clock.t
  method with_after : Clock.t -> 'self
end

(** Use the provided CQRS context creation function to create that context
    and evaluate a thread. When the thread returns or fails, closes the CQRS 
    context. It should not be used anymore after that. *)
val using : config -> (cqrs -> (#ctx as 'ctx)) -> ('ctx, 'a) Run.t -> ('any, 'a) Run.t 

(** An event writer is a function that writes events of the specified type to 
    an underlying stream. *)
type ('ctx, 'a) event_writer = 'a list -> ( 'ctx , Clock.t ) Run.t

module Names : sig

  (** A name prefix, used by projection-dependent structures to create tables in the
      database. *)
  type prefix 

  (** Returns the full database name for a view. Only call this once for
      a given view name. *)
  val view : ?prefix:prefix -> string -> int -> ( ctx, string ) Run.t

  (** Same as {!view}, but creates an independent view and does not require
      a database read to generate (because there is no need to query for a 
      projection version). *)
  val independent : string -> int -> string

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

  (** Wait for a projection to reach a given clock. Returns once the
      clock has been reached. May throw [Projection.LeftBehind] if it
      times out. If no clock is provided, uses the current [ctx # after]
      instead. *)
  val wait : ?clock:Clock.t -> t -> (#ctx, unit) Run.t

  (** Raised if waiting on a projection for too long.
      [LeftBehind (projection, current, expected)] *)
  exception LeftBehind of string * Clock.t * Clock.t

  (** Create a projection from a name and a database configuration. *)
  val make : string -> config -> t

  (** [register kind name version] registers an view of type [kind] called
      [name] at version number [version]. 

      This is used to automatically 
      increment the projection version number based on its contents. *)
  val view : t -> string -> int -> view
    
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

(** A stream is a persistent sequence of events. Each object is a custom object (a type
    serializer is required to create the stream). In the stream, it is attached to a 
    creation time (used mostly for information purposes: the precision of the timestamp
    is probably worse than 60 seconds) and a database identifier (because events from
    multiple databases may be added to a single stream, and RunOrg needs to support
    sharding or exporting databases). *)
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

(** A set of keys. *)
module SetView : sig

  (** A persistent set. *)
  type 'key t

  (** Create a set from a key type, which must support packing. A set always 
      has a name and is placed inside a projection. *)
  val make : Projection.t -> string -> int ->
    (module Fmt.FMT with type t = 'key) ->
    Projection.view * 'key t
      
  (** Add elements to a set. Nothing happens to elements already in the set. *)
  val add : 'key t -> 'key list -> # ctx Run.effect

  (** Removes elements from a set. Nothing happens to elements not in the set. *)
  val remove : 'key t -> 'key list -> # ctx Run.effect

  (** Determines whether an element exists in the set. *)
  val exists : 'key t -> 'key -> (#ctx, bool) Run.t

end

(** Feed-maps bind time-sorted lists of values to keys. *)
module FeedMapView : sig

  (** A map of feeds, bound to type ['key], with each feed item of type ['value]
      having an identifier of type ['id] *)
  type ('key, 'id, 'value) t

  (** Create a feed map. All types must support packing. A feed map always has a
      name and is placed inside a projection. *)
  val make : Projection.t -> string -> int ->
    (module Fmt.FMT with type t = 'key) ->
    (module Fmt.FMT with type t = 'id) ->
    (module Fmt.FMT with type t = 'value) ->
    Projection.view * ('key, 'id, 'value) t

  (** Update a map value. *)
  val update : ('key, 'id, 'value) t -> 'key -> 'id -> 
    ((Time.t * 'value) option -> [ `Keep | `Put of (Time.t * 'value) | `Delete]) ->
    # ctx Run.effect

  (** Delete a feed. *)
  val delete : ('key, 'id, 'value) t -> 'key -> # ctx Run.effect

  (** Does an item exist in the specified feed ? *)
  val exists : ('key, 'id, 'value) t -> 'key -> 'id -> (#ctx, bool) Run.t

  (** How many items in a feed, and when are the first and last elements ? *)
  val stats : ('key, 'id, 'value) t -> 'key -> (#ctx, <
    count : int ;
    first : Time.t option ;
    last  : Time.t option ;
  >) Run.t

  (** List elements in a feed, in reverse chronological order (latest 
      first). *)
  val list : ('key, 'id, 'value) t -> ?limit:int -> ?offset:int -> 'key ->
    (#ctx, ('id * Time.t * 'value) list) Run.t
 
end

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

  (** Checks if a value in a map exists. *)
  val exists : ('key, 'value) t -> 'key -> (# ctx, bool) Run.t

  (** Grabs all values from the map, ordered by the binary representation of the key. *)
  val all : ?limit:int -> ?offset:int -> ('key,'value) t ->
    (# ctx, ('key * 'value) list) Run.t

  (** Grabs all values from the map, ordered by the binary representation of the key, 
      for all databases. This is a potential data leak, use with caution. *)
  val all_global : ?limit:int -> ?offset:int -> ('key,'value) t ->
    (# ctx, (Id.t * 'key * 'value) list) Run.t

  (** Returns the number of key-value pairs in the map. *)
  val count : ('key,'value) t -> (#ctx, int) Run.t

end

(** Many-to-many maps bind identifiers to identifiers. *)
module ManyToManyView : sig

  (** The type of a many-to-many map. *)
  type ('left, 'right) t

  (** Create a map from a left type and a right type. Both types must support 
      packing. A map always has a name, and is placed inside a projection. *)
  val make : Projection.t -> string -> int -> 
    (module Fmt.FMT with type t = 'left) ->
    (module Fmt.FMT with type t = 'right) ->
    Projection.view * ('left, 'right) t

  (** Flips a view to allow queries in the other direction. *)
  val flip : ('left, 'right) t -> ('right, 'left) t 

  (** Adds the cartesian product of the two provided sets to the 
      map. Nothing happens to bindings already in the map. *)
  val add : ('left, 'right) t -> 'left list -> 'right list -> # ctx Run.effect
    
  (** Remove the cartesian product of the two provided sets from the
      map. Nothing happens to bindings not present in the map. *)
  val remove : ('left, 'right) t -> 'left list -> 'right list -> # ctx Run.effect

  (** Checks whether a binding exists in the map. *)
  val exists : ('left, 'right) t -> 'left -> 'right -> (# ctx, bool) Run.t

  (** Deletes all the bindings with the specified left member. *)
  val delete : ('left, 'right) t -> 'left -> # ctx Run.effect

  (** List all the bindings with the specified left member. *)
  val list : ?limit:int -> ?offset:int -> ('left, 'right) t -> 'left -> (# ctx, 'right list) Run.t

  (** List all the right-values that are bound to at least one left-value in the
      provided list. *)
  val join : ?limit:int -> ?offset:int -> ('left, 'right) t -> 'left list -> (# ctx, 'right list) Run.t

  (** Count the bindings with the specified left value. *)
  val count : ('left, 'right) t -> 'left -> (# ctx, int) Run.t 

end

(** Search views index elements by their text contents. *)
module SearchView : sig

  type ('id) t

  (** Create a new search index that contains values of type ['id] indexed
      by strings. *)
  val make : Projection.t -> string -> int ->
    (module Fmt.FMT with type t = 'id) ->
    Projection.view * 'id t

  (** Bind a value to several words. Provide an empty list to 
      completely unbind a value. *)
  val set : 'id t -> 'id -> string list -> # ctx Run.effect

  (** Finds all values tied to a specific string. Unlike [find_exact], 
      prefix matches are allowed. *)
  val find : ?limit:int -> 'id t -> string -> (#ctx, 'id list) Run.t

  (** Finds all values tied to a specific string. Only exact matches are 
      allowed. *)
  val find_exact : ?limit:int -> 'id t -> string -> (#ctx, 'id list) Run.t

end

(** Keeping track of running instances. *)
module Running : sig

  (** Thrown when a shutdown is requested. *)
  exception Shutdown 

  (** Ask for all instances to shut down. *)
  val reset : config -> unit

  (** Long-running thread, marks the instance as still
      running. Throws [Shutdown] (and breaks out of eval) when 
      a shutdown is requested. *)
  val heartbeat : config -> unit Run.thread

end

(** Module for running SQL queries directly. *)
module Sql : sig

  (** The type of parameters to raw queries. *)
  type param = [ `Binary of string
	       | `String of string 
	       | `Id of Id.t
	       | `Int of int ] 

  (** The type of raw results. *)
  type raw_result = string array array

  (** Runs a query asynchronously. Queries are sequential (that is, 
      they are executed in the order they are provided in), but the
      asynchronous interface lets the program perform other operations
      while queries are running. *)

  val query : string -> param list -> ( #ctx, raw_result ) Run.t 

  (** A safe query will block if a transaction is active (until the 
      transaction ends). *)

  val safe_query : string -> param list -> (#ctx, raw_result ) Run.t

  (** Like a query, but with no result expected. *)

  val command : string -> param list -> #ctx Run.effect

  (** Runs specific code on the first connection. *)

  val on_first_connection : ctx Run.effect -> unit

  (** Executes an operation inside a transaction *)

  val transaction : (#ctx as 'ctx, 'a) Run.t -> ( 'ctx, 'a ) Run.t

end

module Result : sig
    
  (** If the returned result contains a top-left cell, unpack that 
    cell with the provided unpacker. Otherwise, return [None]. *)
  val unpack : Sql.raw_result -> 'a Pack.unpacker -> 'a option
    
end

