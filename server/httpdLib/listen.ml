(* © 2013 RunOrg *)

open Std
open Common

let start config handler = 

  let channel = Event.new_channel () in 

  let _ = Thread.create begin fun channel -> 
    while true do 
      let start = Unix.gettimeofday () in
      Event.sync (Event.send channel "Hello") ;
      let finish = Unix.gettimeofday () in
      Log.trace "Event waited %f seconds" ((finish -. start) /. 1000.) ;
      Thread.delay 3.0
    done 
  end channel in 

  let rec process () = 
    let! request = Run.of_channel channel in
    process () 
  in

  process ()

