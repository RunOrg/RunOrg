(** A database connection. This is an internal type that you should not use. *)
type cqrs

(** Configuration object for connecting to a PostgreSQL database. *)
type config = {
  cfg_host : string ;
  cfg_port : int ;
  cfg_database : string ;
  cfg_user : string ;
  cfg_password : string 
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

(** Event wrappers. *)
type 'a event_wrapper = <
  clock : Clock.t ;
  event : 'a ;
  time  : Time.t ; 
>

(** Resumable event streams *)
type ('ctx, 'a) stream = Clock.t -> ( 'ctx, 'a event_wrapper ) Seq.t 

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
    
  (** Reads events from the stream, starting at the specified position. This is
      a finite sequence, which ends at the last event currently in the store. *)
  val read : ( #ctx, event ) stream 

  (** Reads events from the stream, starting at the specified position. This is
      an infinite sequence, which waits for new events to appear in the stream. *)
  val follow : ( #ctx, event ) stream 

end

(** Creates a new stream with the specified name and (packable) event type. *)
module Stream : functor(Event:sig 
  include Fmt.FMT 
  val name : string 
end) -> STREAM with type event = Event.t

module Names : sig

  (** A name prefix, used by projection-dependent structures to create tables in the
      database. *)
  type prefix 

end

(** Create a new projection with a name and version number. Several projections 
    with the same name but different version numbers may exist in the database.
    
    Once the projection with the latest version number has caught up 
    with all its underlying streams, the previous version numbers may be 
    deleted to save space. 
    
    Inside the database, tables involved in the projection will be prefixed with 
    'proj:{thename}:{theversion}' 
*)

class ['ctx] projection : (#ctx as 'ctx) Lazy.t -> string -> object 

  (** [p # register kind name version] registers an object of kind [kind] called
      [name] at version number [version]. This is used to automatically 
      increment the projection version number based on its contents. *)
    
  method register : string -> string -> int -> Names.prefix

  (** The current clock of this projection. *)

  method clock : ('ctx, Clock.t) Run.t

  (** Start tracking a new event stream, perform the specified action for 
      every event. Actions will be executed as part of a transaction, in the
      same order as they were in the stream, and only once. *)
    
  method on : 'event. ('ctx,'event) stream -> ('event -> 'ctx Run.effect) -> unit 

end

(** Runs all registered projections in parallel. If any projections use infinite event
    streams such as [Stream.follow], this function runs unitil a reset is requested
    using [Cqrs.Running.reset ()] from another process. *)

val run_projections : unit -> unit Run.thread

(** Maps bind values to keys. *)

module MapView : sig

  (** A persistent map *)

  type ('key, 'value) t 

  (** Create a map from a key type and a value type. Both types must support 
      packing. A map always has a name, and may be placed inside a projection 
      (if it is updated by a projection). *)
  val make : ?projection:('any projection) -> string -> int -> 
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
