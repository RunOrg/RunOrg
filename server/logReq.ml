(* © 2014 RunOrg *)

open Run

let enabled = true

(* Context management 
   ================== *)

type t = {
  mutable ip : string ;
  mutable path : string ; 
  time : float ;
}

class type ctx = object ('self) 
  method logreq : t 
end

class log_ctx = object
  val log = { ip = "" ; path = "" ; time = Unix.gettimeofday () }
  method logreq = log
end

let start inner = 
  Run.with_context (new log_ctx :> ctx) inner

let set_request_ip str = 
  if enabled then 
    let! ctx = Run.context in 
    return ((ctx # logreq).ip <- (str ^ " | "))
  else
    return ()

let set_request_path str = 
  if enabled then 
    let! ctx = Run.context in 
    return ((ctx # logreq).path <- (str ^ " | "))
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
      return (Log.trace "%s%s%s %.2fms" log.ip log.path str 
		(1000. *. (time -. log.time)))
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
