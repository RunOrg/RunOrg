(* © 2013 RunOrg *)

type ('key, 'value) t 

val make : Projection.t -> string -> int -> 
  (module Fmt.FMT with type t = 'key) ->
  (module Fmt.FMT with type t = 'value) ->
  Projection.view * ('key, 'value) t

val standalone : string -> int -> 
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

val exists : ('key, 'value) t -> 'key -> (# Common.ctx, bool) Run.t

val all : ?limit:int -> ?offset:int -> ('key,'value) t ->
  (#Common.ctx, ('key * 'value) list) Run.t

val all_global : ?limit:int -> ?offset:int -> ('key,'value) t ->
  (#Common.ctx, (Id.t * 'key * 'value) list) Run.t

val count : ('key,'value) t -> (#Common.ctx, int) Run.t
