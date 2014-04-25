(* © 2014 RunOrg *)

module Parse = struct

  (* Default location, can be overriden by flag. *)
  let override = 
    try let i = BatArray.findi (fun s -> s = "-config") Sys.argv in
	if i < Array.length Sys.argv then Some Sys.argv.(i) else None
    with Not_found -> None
      
  (* Secondary overload: conf.ini in the same directory *)
  let path = 
    match override with Some path -> path | None -> 
      try close_in (open_in "./conf.ini") ; "./conf.ini" with _ -> "/etc/runorg/conf.ini"

  let lines = 
    try let chan = open_in path in 
	let rec read acc = 
	  let line = try Some (input_line chan) with _ -> None in 
	  match line with None -> List.rev acc | Some line -> read (line :: acc) 
	in
	let lines = read [] in
	close_in chan ; lines
    with exn -> 
      Printf.printf "When reading configuration file %S:\n%s\n%!"
	path (Printexc.to_string exn) ;
      exit (-1)

  (* Removes comments *)
  let lines = 
    List.map (fun s -> 
      BatString.trim 
	(try let i = String.index s ';' in
	     String.sub s 0 i
	 with Not_found -> s)) lines

  (* Removes empty lines *)
  let lines = 
    List.filter (fun s -> s <> "") lines
 
  let assoc = 
    List.fold_left (fun acc s -> 
      try let i = String.index s '=' in 
	  let key = BatString.trim (String.sub s 0 i) in
	  let value = BatString.trim (String.sub s (i+1) (String.length s - i - 1)) in
	  (key,value) :: acc
      with Not_found -> acc) [] lines
      
  let string key default = 
    try List.assoc key assoc with Not_found -> default

  let req key = 
    try List.assoc key assoc with Not_found -> 
      Printf.printf "Required field %s not found in configuration file %S\n%!"
	key path ;
      exit (-1)

  let int key default = 
    try int_of_string (List.assoc key assoc) with 
    | Not_found -> default
    | exn -> 
      Printf.printf "When reading integer field %s in configuration file %S:\n%s\n%!"
	key path (Printexc.to_string exn) ;
      exit (-1)

  let float key default = 
    try float_of_string (List.assoc key assoc) with 
    | Not_found -> default
    | exn -> 
      Printf.printf "When reading number field %s in configuration file %S:\n%s\n%!"
	key path (Printexc.to_string exn) ;
      exit (-1)

  let size key default bound = 
    try let s = List.assoc key assoc in
	let n = String.length s - 1 in 
	let s, m = match s.[n] with 
	  | 'K' | 'k' -> String.sub s 0 n, 1024
	  | 'M' | 'm' -> String.sub s 0 n, (1024 * 1024)
	  | _ -> s, 1 in
	let size = int_of_string s * m in
	if bound then min Sys.max_string_length size else size
    with 
    | Not_found -> default
    | exn -> 
      Printf.printf "When reading size field %s in configuration file %S:\n%s\n%!"
	key path (Printexc.to_string exn) ;
      exit (-1)

  let emails key =
    try List.map BatString.trim (BatString.nsplit (List.assoc key assoc) " ") with 
    | Not_found -> 
      Printf.printf "Required field %s not found in configuration file %S\n%!"
	key path ;
      exit (-1)	
    | exn -> 
      Printf.printf "When reading email field %s in configuration file %S:\n%s\n%!"
	key path (Printexc.to_string exn) ;
      exit (-1)

  let error key what = 
    Printf.printf "When reading field %s in configuration file %S:\n%s"
      key path what ;
    exit (-1)

end

type role = [ `Run | `Reset ]

let path = Parse.path

let test = Parse.string "test" "disabled" = "enabled"

let role =
  if BatArray.mem "reset" Sys.argv then `Reset else `Run

let to_stdout = 
  BatArray.mem "-stdout" Sys.argv
    

module Log = struct

  let prefix = Parse.string "log.directory" "/var/log/runorg/"
  let prefix = if to_stdout then None else Some prefix

  let httpd = match Parse.string "log.httpd" "none" with
    | "none"  -> `None
    | "trace" -> `Trace
    | "debug" -> `Debug
    | unknown -> Parse.error "log.httpd" ("Unknown log level: " ^ unknown)

end

module Database = struct
  let host      = Parse.string "db.host" "localhost" 
  let port      = Parse.int    "db.port" 5432 
  let database  = Parse.string "db.name" "runorg" 
  let user      = Parse.req    "db.user" 
  let password  = Parse.req    "db.password"
  let poll      = Parse.float  "db.poll" 1000.0
  let pool_size = Parse.int    "db.pool-size" 10 
end

(* eg vnicollet@runorg.com, foo.bar@example.com *)
let admins = Parse.emails "admin.list"

(* eg "https://runorg.local:4443" *)
let admin_audience = Parse.req "admin.audience"

module Httpd = struct
  let port             = Parse.int   "httpd.port" 443 
  let key_path         = Parse.req   "httpd.key" 
  let certificate_path = Parse.req   "httpd.certificate"
  let key_password     = Parse.req   "httpd.key.password"
  let max_header_size  = Parse.size  "httpd.max.header-size" 4096 true
  let max_body_size    = Parse.size  "httpd.max.body-size" (1024*1024) true
  let max_duration     = Parse.float "httpd.max.duration" 1.0
end

let token_key = Parse.req "token.key"

(* eg "https://runorg.local:4443" *)
module Mail = struct

  let url = Parse.req "mail.url"

end
