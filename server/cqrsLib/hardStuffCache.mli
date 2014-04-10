(* © 2014 RunOrg *)

type ('key,'value) t

val make : string -> int -> 
  (module Fmt.FMT with type t = 'key) ->
  (module Fmt.FMT with type t = 'value) ->
  ('key -> (Common.ctx, 'value) Run.t) -> 
  ('key,'value) t
    
val get : ('key,'value) t -> 'key -> Clock.t -> (#Common.ctx,'value) Run.t
