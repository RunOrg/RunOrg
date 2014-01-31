(* © 2013 RunOrg *)

module OpenHack = struct
  (* Open a few modules because they are only used by internal libraries, 
     and the ocamlbuild depencency solver does not build them. *)
  open Seq
  open Token
  open Persona
  open ServerAdmin
  open Db
  open Contact
  open Gravatar
  open Group
  open Chat
  open Test
  open CustomId
end

let () = Printexc.record_backtrace true

let mkctx () = new O.ctx
  
(* Interrupt the program if a "shutdown" exception is raised. *)
let exn_handler = function 
  | Cqrs.Running.Shutdown -> false
  | _ -> true

let run_loop () = 
  Log.trace "RunOrg %s starting ; config: %s" RunorgVersion.version_string Configuration.path ;
  let respond = Api.run () in
  begin 
    try 
      Run.start ~exn_handler () [
	Cqrs.Running.heartbeat (mkctx ()) ;	
	Cqrs.Projection.run () ;      
	respond
      ]
    with Cqrs.Running.Shutdown -> () 
  end ;
  exit 0
 
let () =   
  match Configuration.role with
  | `Run -> run_loop ()
  | `Reset -> Log.trace "Starting global reset ; config: %s" Configuration.path ; Cqrs.Running.reset (mkctx ())
    


