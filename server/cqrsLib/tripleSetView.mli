(* © 2014 RunOrg *)

type ('a,'b,'c) t

val make : Projection.t -> string -> int ->
  (module Fmt.FMT with type t = 'a) ->
  (module Fmt.FMT with type t = 'b) ->
  (module Fmt.FMT with type t = 'c) ->
  Projection.view * ('a,'b,'c) t
    
val flipBC : ('a,'b,'c) t -> ('a,'c,'b) t
  
val flipAB : ('a,'b,'c) t -> ('b,'a,'c) t
  
val add : ('a,'b,'c) t -> 'a -> 'b -> 'c list -> # Common.ctx Run.effect
  
val remove : ('a,'b,'c) t -> 'a -> 'b -> 'c list -> # Common.ctx Run.effect
  
val delete : ('a,'b,'c) t -> 'a -> # Common.ctx Run.effect
  
val delete2 : ('a,'b,'c) t -> 'a -> 'b -> # Common.ctx Run.effect
  
val all2 : ('a,'b,'c) t -> ?limit:int -> ?offset:int -> 'a -> 'b -> (#Common.ctx, 'c list) Run.t
  
val all : ('a,'b,'c) t -> ?limit:int -> ?offset:int -> 'a -> (#Common.ctx, ('b * 'c) list) Run.t
  
val intersect : ('a,'b,'c) t -> 'a -> 'b -> 'c list -> (#Common.ctx, 'c list) Run.t
