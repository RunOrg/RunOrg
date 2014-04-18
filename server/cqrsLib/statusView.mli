(* © 2014 RunOrg *)

type ('key, 'status) t 

val make : Projection.t -> string -> int -> 'status ->
  (module Fmt.FMT with type t = 'key) ->
  (module Fmt.FMT with type t = 'status) ->
  Projection.view * ('key, 'status) t
    
val update : ('key, 'status) t -> 'key -> ('status -> 'status) -> # Common.ctx Run.effect
val get : ('key, 'status) t -> 'key -> (# Common.ctx, 'status) Run.t
val global_by_status : ?limit:int -> ?offset:int -> ('key, 'status) t -> 'status 
  -> (#Common.ctx, (Id.t * 'key) list) Run.t 
