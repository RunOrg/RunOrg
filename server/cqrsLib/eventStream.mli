open Common

type ('ctx, 'a) event_writer = 'a list -> ( 'ctx, unit ) Run.t

type 'a event_wrapper = <
  clock : Clock.t ;
  event : 'a ;
  time  : Time.t ; 
>

type ('ctx, 'a) stream = Clock.t -> ( 'ctx, 'a event_wrapper ) Seq.t 

module type STREAM = sig
  type event
  val name : string
  val append : ( #ctx, event ) event_writer
  val count : unit -> ( #ctx, int ) Run.t
  val clock : unit -> ( #ctx, Clock.t ) Run.t
  val read : ( #ctx, event ) stream 
  val follow : ( #ctx, event ) stream
end

module Stream : functor(Event:sig 
  include Fmt.FMT
  val name : string 
end) -> STREAM with type event = Event.t
