open Common

type ('ctx, 'a) event_writer = 'a list -> ( 'ctx, unit ) Run.t

module type STREAM = sig
  type event
  val name : string
  val append : ( #ctx, event ) event_writer
  val count : unit -> ( #ctx, int ) Run.t
  val clock : unit -> ( #ctx, Clock.t ) Run.t
  val track : Projection.view -> (event -> ctx Run.effect) -> unit
end

module Stream : functor(Event:sig 
  include Fmt.FMT
  val name : string 
end) -> STREAM with type event = Event.t
