(* © 2013 RunOrg *)


(* Recursively ensures that a directory exists. *)
let rec mkdir dir = 
  let parent = Filename.dirname dir in 
  if dir <> "" & parent <> dir then begin
    mkdir parent ; 
    try 
      if not (Sys.is_directory dir) then 
	failwith (dir ^ " exists but is not a directory")
    with Sys_error _ -> 
      try Unix.mkdir dir 0o755
      with exn -> 
	(Printf.printf "While creating directory %S:\n%s" dir 
	   (Printexc.to_string exn)) ;
	exit (-1) 
  end

(* Writes a string to a file. *)
let write_file path contents = 
  let chan = open_out path in 
  output_string chan contents ;
  close_out chan ;
  Printf.printf "%s: %d bytes\n%!" path (String.length contents) 

let write dir build = 
  mkdir dir ;
  let less = Filename.concat dir "all.less.css" in
  write_file (Filename.concat dir "all.js") build.Build.js ; 
  write_file less build.Build.css ;
  List.iter (fun (lang,script) -> write_file (Filename.concat dir (lang ^ ".js")) script)
    build.Build.i18n ;
  LessCss.compile less (Filename.concat dir "all.css")

