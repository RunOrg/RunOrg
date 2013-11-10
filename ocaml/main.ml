open Ohm

open User

let () = Printexc.record_backtrace true
let () = Ohm.Main.run (fun () -> new O.ctx) 

