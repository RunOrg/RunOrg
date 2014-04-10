(* © 2014 RunOrg *)

type cqrs

val trace_events : bool

type config = {
  host : string ;
  port : int ;
  database : string ;
  user : string ;
  password : string ;
  pool_size : int ;
}

exception ConnectionFailed of string

class type ctx = object ('self)
  method cqrs : cqrs
  method time : Time.t 
  method with_time : Time.t -> 'self
  method db : Id.t
  method with_db : Id.t -> 'self
  method after : Clock.t 
  method with_after : Clock.t -> 'self
end 

class cqrs_ctx : cqrs -> object ('self)
  method cqrs : cqrs
  method time : Time.t
  method with_time : Time.t -> 'self
  method db : Id.t
  method with_db : Id.t -> 'self
  method after : Clock.t 
  method with_after : Clock.t -> 'self
end

val on_first_connection : ctx Run.effect ref 

type param = 
  [ `Binary of string 
  | `String of string 
  | `Id of Id.t
  | `Int of int ] 

type result = string array array 

val query : string -> param list -> ( #ctx, result ) Run.t

val make_cqrs : config -> bool -> cqrs
val reset_cqrs : cqrs -> unit
val close_cqrs : cqrs -> unit
