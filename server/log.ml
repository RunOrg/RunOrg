(* © 2013 RunOrg *)

(* Returns the folder path for the specified time. Folder names change daily. *)
let folder_path t = 
  let y, m, d = Time.ymd t in
  Filename.concat Configuration.log_prefix (Printf.sprintf "%04d-%02d-%02d" y m d)
  
(* Returns the file basename for a specified role name. *)
let file_name rolename error = 
  rolename ^ (if error then ".error.log" else ".log")

(* Creates a function that returns the opened channel for the specified time. 
   The file is kept open until the next day. *)
let file role error = 

  (* For reset role, everything goes out to standard output (or error). *)
  if role = `Bot then (if error then (fun _ -> stderr) else (fun _ -> stdout)) else

    let chanref = ref None in 
    let time    = ref Time.(day_only (now ())) in

    fun t ->        

      (* Close the file if it's the wrong day *)
      let t = Time.day_only t in 
      if !time <> t then ( BatOption.may close_out !chanref ; chanref := None ) ; 
      time := t ;
      
      (* Return the channel if it's opened. *)
      match !chanref with Some channel -> channel | None ->

	let rolename = match role with 
	  | `Bot -> "bot"
	  | `Web -> "web"
	  | `Reset -> assert false (* Should have returned STDOUT or STDERR above *)
	in

	(* TODO: catch exceptions below *)

	let folder = folder_path t in
	Unix.mkdir folder 0o644 ; 	

	let path = Filename.concat folder (file_name rolename error) in 
	let channel = open_out_gen [Open_append] 0o644 path in

	chanref := Some channel ;
	channel
	
(* The two log files. *)

let trace_channel = file Configuration.role false
let error_channel = file Configuration.role true

(* The line prefix, added before each line. *)

let pid = Unix.getpid () 
let prefix t = 
  match Time.hms t with None -> assert false | Some (h,i,s) ->
    Printf.sprintf "%02d:%02d:%02d [%5d] " h i s pid

(* Writing to a channel. *)

let write channel t = 
  let channel = channel t in 
  let prefix  = prefix t in 
  Printf.ksprintf 
    (fun string -> 
      output_string channel prefix ; 
      output_string channel string ) 

(* The actual log functions. *)
  
let trace fmt = 
  write trace_channel (Time.now ()) fmt

let error fmt = 
  write error_channel (Time.now ()) fmt
