(* © 2014 RunOrg *)

type ('id) t

val make : Projection.t -> string -> int ->
  (module Fmt.FMT with type t = 'id) ->
  Projection.view * 'id t

val set : 'id t -> 'id -> string list -> # Common.ctx Run.effect

val find : ?limit:int -> 'id t -> string -> (#Common.ctx, 'id list) Run.t

val find_exact : ?limit:int -> 'id t -> string -> (#Common.ctx, 'id list) Run.t
