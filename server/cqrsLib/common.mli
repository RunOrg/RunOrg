(* © 2014 RunOrg *)

type cqrs = SqlConnection.t

val trace_events : bool

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

