(* © 2013 RunOrg *)

(* Returns the folder path for the specified time. Folder names change daily. *)
let folder_path prefix t = 
  let y, m, d = Time.ymd t in
  Filename.concat prefix (Printf.sprintf "%04d-%02d-%02d" y m d)
  
(* Returns the file basename for a specified role name. *)
let file_name rolename error = 
  rolename ^ (if error then ".error.log" else ".log")

(* Creates a function that returns the opened channel for the specified time. 
   The file is kept open until the next day. *)
let file role error = 

  let prefix = match Configuration.log_prefix with 
    | None -> None 
    | _ when role = `Reset -> None 
    | Some prefix -> Some prefix 
  in
  
  match prefix with 
  | None -> if error then (fun _ -> stderr) else (fun _ -> stdout)
  | Some prefix ->
    
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

	let folder = folder_path prefix t in
	( try Unix.mkdir folder 0o755 with Unix.Unix_error (Unix.EEXIST, _, _) -> () ) ; 	

	let path = Filename.concat folder (file_name rolename error) in 
	let channel = open_out_gen [Open_append;Open_creat] 0o644 path in

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
  Printf.ksprintf (fun string -> output_string channel (prefix ^ string ^ "\n") ; flush channel ) 

(* The actual log functions. *)
  
let trace fmt = 
  write trace_channel (Time.now ()) fmt

let error fmt = 
  write error_channel (Time.now ()) fmt

let exn exn backtrace =
  error "%s\n%s" (Printexc.to_string exn) backtrace ;

