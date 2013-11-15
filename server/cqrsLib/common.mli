type cqrs

type config = {
  host : string ;
  port : int ;
  database : string ;
  user : string ;
  password : string 
}

exception ConnectionFailed of string

class type ctx = object
  method cqrs : cqrs
  method time : Time.t 
end 

class virtual cqrs_ctx : config -> object 
  method cqrs : cqrs
  method virtual time : Time.t
end

val on_first_connection : ctx Run.effect ref 

type param = 
  [ `Binary of string 
  | `String of string 
  | `Int of int ] 

type result = string array array 

val query : string -> param list -> ( #ctx, result ) Run.t


