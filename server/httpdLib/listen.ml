(* © 2013 RunOrg *)

open Std
open Common

let start config handler = 

  Https.init () ;
  
  let connections = Event.new_channel () in 

  (* Create and set up a socket for listening to incoming connections
     on the specified port. *)
  let socket = Unix.socket Unix.PF_INET Unix.SOCK_STREAM 0 in
  Unix.setsockopt socket Unix.SO_REUSEADDR true ;
  Unix.bind socket (Unix.ADDR_INET (Unix.inet_addr_any, config.port)) ;  
  Unix.listen socket 10 ; 

  let https = Https.context socket config in 

  (* Called by the HTTPD thread to send a connection to the primary 
     thread. Logs an error if blocked too long (when the scheduler
     is starving events *)
  let send connection = 
    let start = Unix.gettimeofday () in
    Event.sync (Event.send connections connection) ;
    let duration = Unix.gettimeofday () -. start in
    if (duration > 500.) then	
      Log.error "HTTPD event waited %f seconds" (duration /. 1000.) 
  in

  (* This thread listens for connections on the opened port, and
     passes them on to the processor loop below. *)
  let _ = Thread.create begin fun socket ->     
    while true do       
      (* This line blocks while waiting for a new connection. *)
      send (Unix.accept socket)
    done 
  end socket in 

  (* This code handles an incoming connection, as part of the main
     thread. *)
  let handle socket caller = 

    let () = match caller with 
      | Unix.ADDR_UNIX _ -> ()
      | Unix.ADDR_INET (addr,port) -> Log.trace "Connection from %s:%d"
	(Unix.string_of_inet_addr addr) port
    in

    Https.parse https socket config handler

  in

  (* This code runs in the main thread, as part of the scheduler's loop.
     It receives new connections from the HTTP daemon thread, processes them 
     (using the provided handler), and sends back the response. *)
  let rec accept () =    
    let! socket, caller = Run.of_channel connections in
    Run.fork (handle socket caller) (accept ()) 
  in

  accept ()

