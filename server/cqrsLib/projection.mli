class ['ctx] projection : (#Common.ctx as 'ctx) Lazy.t -> string -> object
  method register : string -> string -> int -> Names.prefix 
  method on : 'event. ('ctx,'event) EventStream.stream -> ('event -> 'ctx Run.effect) -> unit 
  method clock : ('ctx, Clock.t) Run.t
end

val run_projections : unit -> unit Run.thread
