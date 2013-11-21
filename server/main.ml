module OpenHack = struct
  (* Open a few modules because they are only used by internal libraries, 
     and the ocamlbuild depencency solver does not build them. *)
  open Seq
  open Token
  open Persona
  open ServerAdmin
end

let () = Printexc.record_backtrace true

let mkctx () = new O.ctx
  
let web_loop () = 
  Log.trace "Starting web server %s" RunorgVersion.version_string ;
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
  Log.trace "Starting background process %s" RunorgVersion.version_string ;
  try 
    Run.start () [
      Cqrs.Running.heartbeat (mkctx ()) ;	
      Cqrs.Projection.run () ;
    ]
  with Cqrs.Running.Shutdown -> () 
  
let () =   
  match Configuration.role with
  | `Web   -> web_loop ()
  | `Bot   -> bot_loop ()
  | `Reset -> Log.trace "Starting global reset." ; Cqrs.Running.reset (mkctx ())
    


