(* © 2014 RunOrg *)

type ('left, 'right) t

val make : Projection.t -> string -> int -> 
  (module Fmt.FMT with type t = 'left) ->
  (module Fmt.FMT with type t = 'right) ->
  Projection.view * ('left, 'right) t

val flip : ('left, 'right) t -> ('right, 'left) t 

val add : ('left, 'right) t -> 'left list -> 'right list -> # Common.ctx Run.effect
  
val remove : ('left, 'right) t -> 'left list -> 'right list -> # Common.ctx Run.effect
  
val exists : ('left, 'right) t -> 'left -> 'right -> (# Common.ctx, bool) Run.t
  
val delete : ('left, 'right) t -> 'left -> # Common.ctx Run.effect
  
val list : ?limit:int -> ?offset:int -> ('left, 'right) t -> 'left -> (# Common.ctx, 'right list) Run.t

val join : ?limit:int -> ?offset:int -> ('left, 'right) t -> 'left list -> (# Common.ctx, 'right list) Run.t

val count : ('left, 'right) t -> 'left -> (# Common.ctx, int) Run.t
