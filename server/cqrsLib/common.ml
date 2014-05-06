(* © 2014 RunOrg *)

let trace_enabled = false
let trace_events  = false

(* First connection queries 
   ======================== *)

let on_first_connection = ref (Run.return ())

(* Context manipulation 
   ==================== *)

type cqrs = SqlConnection.t

class type ctx = object ('self)
  method cqrs : cqrs
  method time : Time.t 
  method with_time : Time.t -> 'self
  method db : Id.t
  method with_db : Id.t -> 'self
  method after : Clock.t 
  method with_after : Clock.t -> 'self
end 

class cqrs_ctx conn = object (self)

  val cqrs = conn
  val mutable first = SqlConnection.is_first_connection conn

  method cqrs = 
    if first then begin
      first <- false ;
      Run.eval (self :> ctx) !on_first_connection 
    end ;
    cqrs

  val time = Time.now () 

  method time = time
  method with_time time = {< time = time >}
      
  val db = Id.of_string "00000000000"

  method db = db
  method with_db db = {< db = db >}

  val after = Clock.empty

  method after = after
  method with_after after = {< after = after >}

end

