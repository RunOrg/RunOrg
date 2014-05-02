(* © 2013 RunOrg *)

open Std
open Common

type 'ctx handler = Request.t -> ('ctx, Response.t) Run.t

let start config handler = 

  Https.init () ;
  
  let connections = Event.new_channel () in 

  let incr_recycles, zero_recycles = 

    let n = ref 0 in
    let l = Mutex.create () in
    
    (fun () -> Mutex.lock l ; incr n ; Mutex.unlock l),
    (fun () -> Mutex.lock l ; let n' = !n in n := 0 ; Mutex.unlock l ; n')

  in

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
  
  (* Asks for the socket to be shut down and recycled. Called by the
     main thread. *)
  let recycle socket = 
    let () = try Unix.close socket with _ -> () in		  
    incr_recycles () ;
    return () 
  in

  (* This thread listens for connections on the opened port, and
     passes them on to the processor loop below. *)
  let _ = Thread.create begin fun socket ->     

    (* All sockets are passed back to this thread in order to be closed. 
       This lets the thread count the number of open connections. This
       function decrements then number of opened sockets based on the 
       current recycle requests in the channel. *)
    let rec recycle opened = 
      if opened = 0 then 0 else 
	let r = zero_recycles () in
	opened - r
    in

    (* This loop accepts connections and passes them to the processor. 
       Will not accept if the connection limit is reached, and will wait 
       for connections to be closed instead. *)      
    let rec loop last opened = 

      let opened = recycle opened in

      if opened >= Configuration.Httpd.max_connections then 
	if Unix.gettimeofday () -. last > 10000.0 then
	  (* Stops the loop (triggers a shutdown) *)
	  Log.error "Spent more than 10s at https connection limit"
	else begin 
	  Log.trace "WARNING: reached https connection limit = %d" opened ;
	  Thread.delay 0.5 ;
	  loop (Unix.gettimeofday ()) opened
	end 
      else 

	(* This line blocks while waiting for a new connection. *)
	let socket, client = Unix.accept socket in
	let () = send socket in
	
	loop (Unix.gettimeofday ()) (opened + 1)  

    in
    
    ( try loop (Unix.gettimeofday ()) 0 with 
    | Unix.Unix_error (Unix.EMFILE, _, _) -> 
      Log.error "httpd listener thread: too many open file descriptors." 
    | exn -> 
      Log.exn exn "httpd listener thread" ) ; 

    (* The listener thread has died: something must have gone terribly wrong.
       Rather than try to salvage the situation, reboot the entire process. *)
    exit (-1) 

  end socket in 

  (* This code runs in the main thread, as part of the scheduler's loop.
     It receives new connections from the HTTP daemon thread, processes them 
     (using the provided handler), and sends back the response. 

     The socket is then recycled by the httpd listener thread. *)
  let rec accept () =    

    let! socket = Run.of_channel connections in

    let process = 
      Run.on_failure 
	(fun exn -> recycle socket)
	(let! () = LogReq.start (Https.parse https socket config handler) in
	 recycle socket) 
    in
      
    Run.fork (fun exn -> return ()) process (accept ()) 

  in

  accept ()

