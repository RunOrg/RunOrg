let () = Printexc.record_backtrace true

let mkctx () = new O.ctx
  
let web_loop () = 
  Log.trace "Starting web server." ;
  let respond = Api.run () in 
  begin 
    try 
      Run.start () [
	Cqrs.Running.heartbeat (mkctx ()) ;
	respond
      ] 
    with Cqrs.Running.Shutdown -> () 
  end ;
  exit 0

let bot_loop () = 
  Log.trace "Starting background process." ;
  try 
    Run.start () [
      Cqrs.Running.heartbeat (mkctx ()) ;	
      Cqrs.run_projections () ;
    ]
  with Cqrs.Running.Shutdown -> () 
  
let () =   
  match Configuration.role with
  | `Web   -> web_loop ()
  | `Bot   -> bot_loop ()
  | `Reset -> Log.trace "Starting global reset." ; Cqrs.Running.reset (mkctx ())
    


