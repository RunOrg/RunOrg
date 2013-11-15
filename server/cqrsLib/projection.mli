(* © 2013 RunOrg *)

type t 
type view 

(* See cqrs.mli for documentation *)

val make : string -> (unit -> Common.ctx) -> t
val view : t -> string -> string -> int -> view
val name : t -> string
val clock : t -> (#Common.ctx, Clock.t) Run.t
val prefix : view -> Names.prefix
val of_view : view -> t

val run : unit -> unit Run.thread

(** Register a stream of actions (abstract type) with a projection.
    The projection will then track this stream when running. *)
val register : view -> (Clock.t -> (Common.ctx, Common.ctx Run.effect * Clock.t) Seq.t) -> unit
