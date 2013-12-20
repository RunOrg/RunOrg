type cqrs

type config = {
  host : string ;
  port : int ;
  database : string ;
  user : string ;
  password : string 
}

exception ConnectionFailed of string

class type ctx = object ('self)
  method cqrs : cqrs
  method time : Time.t 
  method db : Id.t
  method with_db : Id.t -> 'self
end 

class virtual cqrs_ctx : config -> object ('self)
  method cqrs : cqrs
  method virtual time : Time.t
  method db : Id.t
  method with_db : Id.t -> 'self
end

val on_first_connection : ctx Run.effect ref 

type param = 
  [ `Binary of string 
  | `String of string 
  | `Int of int ] 

type result = string array array 

val query : string -> param list -> ( #ctx, result ) Run.t


