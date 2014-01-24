(* © 2014 RunOrg *)
type ('key, 'id, 'value) t

val make : Projection.t -> string -> int ->
  (module Fmt.FMT with type t = 'key) ->
  (module Fmt.FMT with type t = 'id) ->
  (module Fmt.FMT with type t = 'value) ->
  Projection.view * ('key, 'id, 'value) t

val update : ('key, 'id, 'value) t -> 'key -> 'id -> 
  ((Time.t * 'value) option -> [ `Keep | `Put of (Time.t * 'value) | `Delete]) ->
  # Common.ctx Run.effect

val exists : ('key, 'id, 'value) t -> 'key -> 'id -> (#Common.ctx, bool) Run.t

val stats : ('key, 'id, 'value) t -> 'key -> (#Common.ctx, <
  count : int ;
  first : Time.t option ;
  last  : Time.t option ;
>) Run.t

val list : ('key, 'id, 'value) t -> ?limit:int -> ?offset:int -> 'key ->
  (#Common.ctx, ('id * Time.t * 'value) list) Run.t
 
