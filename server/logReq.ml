(* © 2014 RunOrg *)

open Run

let enabled = true

(* Context management 
   ================== *)

type t = {
  id : int ;
  mutable time : float ;
}

class type ctx = object ('self) 
  method logreq : t 
end

let id = ref 0

class log_ctx = object
  val log = { id = (incr id ; !id) ; time = Unix.gettimeofday () }
  method logreq = log
end

let start inner = 
  Run.with_context (new log_ctx :> ctx) inner

let set_request_ip str = 
  if enabled then 
    let! ctx = Run.context in 
    let  log = ctx # logreq in 
    let  time = Unix.gettimeofday () in      
    let () = Log.trace "%04x =========== %s" log.id str in
    return ()
  else
    return ()

let set_request_path str = 
  if enabled then 
    let! ctx = Run.context in 
    let  log = ctx # logreq in 
    let  time = Unix.gettimeofday () in      
    let () = Log.trace "%04x ----------- %s" log.id str in
    return ()
  else
    return () 

(* Printing out 
   ============ *)

let trace = 
  if enabled then 
    fun str ->
      let! ctx = Run.context in 
      let  log = ctx # logreq in 
      let  time = Unix.gettimeofday () in      
      let () = Log.trace "%04x : %4d ms : %s" log.id (int_of_float (1000. *. (time -. log.time))) str in
      let () = log.time <- time in
      return () 
  else 
    fun _ -> return () 

let formatter = Format.std_formatter (* For ikfprintf *)

let tracef fmt = 
  if enabled then 
    let buffer = Buffer.create 100 in
    Format.kfprintf 
      (fun _ -> trace (Buffer.contents buffer))
      (Format.formatter_of_buffer buffer) 
      fmt
  else
    Format.ikfprintf (fun _ -> return ()) formatter fmt
