(* © 2014 RunOrg *)

type ('key,'value) t

val make : Projection.t -> string -> int ->
  (module Fmt.FMT with type t = 'key) ->
  (module Fmt.FMT with type t = 'value) ->
  Projection.view * ('key,'value) t
        
val add : ('key,'value) t -> 'key -> 'value list -> # Common.ctx Run.effect

val remove : ('key,'value) t -> 'key -> 'value list -> # Common.ctx Run.effect

val delete : ('key,'value) t -> 'key -> # Common.ctx Run.effect

val exists : ('key,'value) t -> 'key -> 'value -> (#Common.ctx, bool) Run.t

val intersect: ('key,'value) t -> 'key -> 'value list -> (#Common.ctx, 'value list) Run.t
