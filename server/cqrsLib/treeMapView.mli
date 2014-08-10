(* © 2014 RunOrg *)

type ('key, 'id, 'value) t

type ('id,'value) node = <
  time    : Time.t ;
  id      : 'id ;
  count   : int ;
  value   : 'value ;
  subtree : ('id, 'value) node list 
>

val make : Projection.t -> string -> int ->
  (module Fmt.FMT with type t = 'key) ->
  (module Fmt.FMT with type t = 'id) ->
  (module Fmt.FMT with type t = 'value) ->
  Projection.view * ('key, 'id, 'value) t

val update : ('key, 'id, 'value) t -> 'key -> 'id -> 
  ((Time.t * 'id option * 'value) option -> [ `Keep | `Put of (Time.t * 'id option * 'value) | `Delete]) ->
  # Common.ctx Run.effect

val delete : ('key, 'id, 'value) t -> 'key -> # Common.ctx Run.effect

val exists : ('key, 'id, 'value) t -> 'key -> 'id -> (#Common.ctx, bool) Run.t

val get : ('key, 'id, 'value) t -> 'key -> 'id -> (# Common.ctx, (Time.t * 'value) option) Run.t

val stats : ('key, 'id, 'value) t -> 'key -> (#Common.ctx, <
  count : int ;
  root  : int ;
  first : Time.t option ;
  last  : Time.t option ;
>) Run.t

val list : 
  ('key, 'id, 'value) t -> 
  ?depth:int -> 
  ?limit:int -> 
  ?offset:int -> 
  ?parent:'id -> 
  'key ->
  (#Common.ctx, ('id,'value) node list) Run.t
