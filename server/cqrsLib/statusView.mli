(* © 2014 RunOrg *)

open Std

type ('set, 'key, 'status) t 

val make : Projection.t -> string -> int -> 'status ->
  (module Fmt.FMT with type t = 'set) ->
  (module Fmt.FMT with type t = 'key) ->
  (module Fmt.FMT with type t = 'status) ->
  Projection.view * ('set, 'key, 'status) t
    
val update : ('set, 'key, 'status) t -> 'set -> 'key -> ('status -> 'status) -> # Common.ctx Run.effect
val get : ('set, 'key, 'status) t -> 'set -> 'key -> (# Common.ctx, 'status) Run.t
val count : ('set, 'key, 'status) t -> 'set -> (# Common.ctx, ('status, int) Map.t) Run.t
val global_by_status : ?limit:int -> ?offset:int -> ('set, 'key, 'status) t -> 'status 
  -> (#Common.ctx, (Id.t * 'set * 'key) list) Run.t 
