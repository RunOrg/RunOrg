open Ohm

let () = Printexc.record_backtrace true
let () = Cqrs.run_projections () 
