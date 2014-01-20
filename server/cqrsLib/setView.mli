(* © 2014 RunOrg *)

type 'key t

val make : Projection.t -> string -> int ->
  (module Fmt.FMT with type t = 'key) ->
  Projection.view * 'key t
    
val add : 'key t -> 'key list -> # Common.ctx Run.effect
  
val remove : 'key t -> 'key list -> # Common.ctx Run.effect
  
val exists : 'key t -> 'key -> (#Common.ctx, bool) Run.t
