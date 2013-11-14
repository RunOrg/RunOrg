let () = Printexc.record_backtrace true

let mkctx () = new O.ctx
  
let web_loop () = 
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
  try 
    Run.start () [
      Cqrs.Running.heartbeat (mkctx ()) ;	
      Cqrs.run_projections () ;
    ]
  with Cqrs.Running.Shutdown -> () 
  
let () =   
  match Util.role () with
  | `Web   -> web_loop ()
  | `Bot   -> bot_loop ()
  | `Reset -> Cqrs.Running.reset (mkctx ())
    


