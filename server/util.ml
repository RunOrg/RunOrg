(* © 2013 RunOrg *)

type role = [ `Bot | `Web | `Reset ]

let pid   = Unix.getpid ()

let _role = ref None

let role () =
  match !_role with 
  | Some role -> role 
  | None -> 
    let role = 
      let bot     = ref false 
      and reset   = ref false in 
      Arg.parse [
	"reset", Arg.Set reset, "force other processes to restart" ;
	"bot",   Arg.Set bot,   "run as bot" ;
      ] (fun _ -> ()) "Start an instance of the Ohm server" ;
      if !bot then `Bot else 
	if !reset then `Reset else `Web
    in
    _role := Some role ;
    role 
    
module Logging = struct

  let open_channel = 
    let chanref = ref None in 
    fun () -> 
      match !chanref with 
	| None -> 
	  let path = "-" in
	  let chan = 
	    if path = "-" then stdout
	    else open_out_gen [Open_append] 0666 path
	  in
	  chanref := Some chan ; chan
	| Some chan -> chan 

  let prefix = 
    let cache = ref None in 
    fun () ->
      match !cache with Some prefix -> prefix | None ->
	let prefix = 
	  Printf.sprintf "[%s:%d]" 
	    (match !_role with 
	      | None        -> "---"
	      | Some `Reset -> "RST"
	      | Some `Bot   -> "BOT"
	      | Some `Web   -> "WEB")
	    pid 
	in
	if !_role <> None then cache := Some prefix ;
	prefix 

  let output string = 
    try let channel = open_channel () in 
	let time = Unix.localtime (Unix.gettimeofday ()) in
	let string =
	  Printf.sprintf "[%d/%02d/%02d %02d:%02d:%02d] %s %s\n" 
	    (time.Unix.tm_year + 1900)
	    (1 + time.Unix.tm_mon)
	    (time.Unix.tm_mday)
	    (time.Unix.tm_hour)
	    (time.Unix.tm_min)
	    (time.Unix.tm_sec)
            (prefix ()) 
	    string 
	in
	output_string channel string ;
	flush channel 
    with _ -> () 

end

let string_of_time time = 
  let time = Unix.gmtime time in 
  Printf.sprintf "%04d%02d%02d%02d%02d%02d"
    (time.Unix.tm_year + 1900)
    (1 + time.Unix.tm_mon)
    (time.Unix.tm_mday)
    (time.Unix.tm_hour)
    (time.Unix.tm_min)
    (time.Unix.tm_sec)
    
let log format = 
  Printf.ksprintf Logging.output format
  


 
