
type ('key, 'value) t 

val make : ?projection:('any Projection.projection) -> string -> int -> 
  (module Fmt.FMT with type t = 'key) ->
  (module Fmt.FMT with type t = 'value) ->
  ('key, 'value) t

val update : ('key, 'value) t -> 'key -> 
  ('value option -> [ `Keep | `Put of 'value | `Delete ]) -> 
  #Common.ctx Run.effect

val mupdate : ('key, 'value) t -> 'key -> 
  ('value option -> (#Common.ctx as 'ctx, [ `Keep | `Put of 'value | `Delete ]) Run.t) -> 
  'ctx Run.effect

val get : ('key, 'value) t -> 'key -> (# Common.ctx, 'value option) Run.t

