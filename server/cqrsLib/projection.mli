(* © 2014 RunOrg *)

type t 
type view 

(* See cqrs.mli for documentation *)

val make : string -> SqlConnection.config -> t
val view : t -> string -> int -> view
val name : t -> string
val clock : t -> (#Common.ctx, Clock.t) Run.t
val prefix : view -> Names.prefix
val of_view : view -> t
val wait : ?clock:Clock.t -> t -> (#Common.ctx, unit) Run.t

exception LeftBehind of string * Clock.t * Clock.t

val run : unit -> unit Run.thread

(** Register a stream of actions (abstract type) with a projection.
    The projection will then track this stream when running. Returns 
    a service that should be pinged when new events are available. *)
val register : view -> (Clock.t -> (Common.ctx, Common.ctx Run.effect * Clock.t) Seq.t) -> Run.service
