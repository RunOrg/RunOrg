(* © 2013 RunOrg *)

open Std
open Common

exception HeaderTooLong
exception BodyTooLong
exception Timeout
exception SyntaxError of string
exception NotImplemented of string

(* Request parser logging 
   ====================== *)

let log_enabled = false

(* A parsed HTTP request
   ===================== *)

type t = <

  host : string ; 
  client_ip : IpAddress.t ; 
  path : string list ; 

  verb : [ `GET | `PUT | `POST | `DELETE ] ;
  body : [ `JSON of Json.t | `Raw of string ] option ;

  headers : (string, string) Map.t ;
  params : (string, string) Map.t ;

  token : Token.I.t option ;
  at : Cqrs.Clock.t option ; 
  limit : int option ;
  offset : int option ; 

  content_type : string option ; 

  accept: [ `JSON | `MSGPACK ] ;
> ;;

let to_string req = 
  !! "%s /%s" 
    (match req # verb with
    | `PUT -> "PUT"
    | `GET -> "GET"
    | `POST -> "POST"
    | `DELETE -> "DELETE") 
    (String.concat "/" req # path) 

(* Decoding functions 
   ================== *)

let decode_regexp = Str.regexp "%[0-9A-Za-z][0-9A-Za-z]"

let decode_char sub = 
  try 
    let h = Char.base36_decode sub.[1] and l = Char.base36_decode sub.[2] in
    String.of_char (Char.chr (h * 16 + l))
  with _ -> 
    raise (SyntaxError ("Could not url-decode " ^ sub))

let urldecode str = 

  let has_percent = ref false in 
  for i = 0 to String.length str - 1  do 
    match str.[i] with 
    | '+' -> str.[i] <- ' ' 
    | '%' -> has_percent := true 
    |  _  -> () 
  done ;

  if !has_percent then
    Str.global_substitute decode_regexp decode_char str
  else
    str

(* Low-level header parsing 
   ======================== *)

let expects_body header = 
  String.starts_with header "POST" || String.starts_with header "PUT" 

let content_length_regexp = Str.regexp "Content-Length: +\\([0-9]+\\)"

let expected_body_size header = 
  try 
    let _ = Str.search_forward content_length_regexp header 0 in
    let group = Str.matched_group 1 header in 
    try int_of_string group with _ -> 0 
  with Not_found -> 0

(* Reading requests from sockets
   ============================= *)

let read_request config ssl_socket = 

  let timeout = Unix.gettimeofday () +. config.max_duration in 
  
  (* Read the entire header, plus any additional data after the end of the
     header. *)
  let read_header () = 
    let buffer = String.create 1024 in
    let header = Buffer.create 1024 in
    let rec more retries =       

      let l  = try Ssl.read ssl_socket buffer 0 1024 with Ssl.Read_error Ssl.Error_want_read -> 0 in
      let () = Buffer.add_substring header buffer 0 l in

      if log_enabled then 
	Log.trace "Read header %d (total %d/%d): \n%s" l (Buffer.length header) (config.max_header_size)
	  (String.sub buffer 0 l) ;

      if Buffer.length header = config.max_header_size then 
	raise HeaderTooLong 
      else if String.exists (Buffer.contents header) "\r\n\r\n" then 
	return ()
      else if l = 0 then 
	let now = Unix.gettimeofday () in 
	if now > timeout then raise Timeout else 
	  let! () = Run.sleep (delay retries timeout now) in
	  more (retries + 1) 
      else 
	more 0 

    in
    let! () = more 0 in
    let header = Buffer.contents header in 
    
    (* Look for a header termination... *)
    let pos = try String.find header "\r\n\r\n" with _ -> raise HeaderTooLong in
    let clean_header = String.sub header 0 pos in 
    let body_start = 
      if String.length header - pos <= 4 then "" else  
	String.sub header (pos + 4) (String.length header - pos - 4)
    in 
    return (clean_header, body_start)
  in

  (* Read the entire body, up to the specified size, with a start size *)
  let read_body start size = 
    if size = 0 then return "" else 

      let i = String.length start in 

      if log_enabled && i > 0 then 
	Log.trace "Initial body:\n%s" start ;

      let body = String.create size in 
      let () = String.blit start 0 body 0 i in

      let rec more retries i = 

	let l = try Ssl.read ssl_socket body i (size - i) with Ssl.Read_error Ssl.Error_want_read -> 0 in
	let i = i + l in
	  
	if log_enabled then 
	  Log.trace "Read %d (total %d/%d): \n%s" l i size
	    (String.sub body (i-l) l) ;
	
	  if i = size then return ()
	  else if l = 0 then 
	    let now = Unix.gettimeofday () in 
	  if now > timeout then raise Timeout else 
	    let! () = Run.sleep (delay retries timeout now) in
	    more (retries + 1) i
	else
	  more retries i 

      in

      let! () = more 0 i in
      
      ( if log_enabled then
	  Log.trace "Body:\n%s" body ;
		
	return body )

  in
	  
  let! header, body = read_header () in     

  if expects_body header then begin 

    let size = expected_body_size header in 

    if log_enabled then 
      Log.trace "Expecting body of size %d" size ; 

    if size > config.max_body_size then raise BodyTooLong else 

      let! body = read_body body size in 
      
      return (header, Some body) 

  end else
    
    ( if log_enabled then 
	Log.trace "No body expected" ; 
      
      return (header, None) ) 
  
(* Request parsing
   =============== *)

let parse_header line = 
  let open String in 
  let line = trim line in
  if line = "" then None else 
    try 
      let name, value = split line ":" in 
      Some ( trim (uppercase name), trim value )
    with exn -> raise (SyntaxError ("Invalid header: " ^ line))

let parse_headers headers = 
  let lines = String.nsplit headers "\r\n" in
  List.to_map fst snd (List.filter_map parse_header lines) 

let parse_param pair =
  let open String in 
  if pair = "" then None else
    try let key, value = split pair "=" in
	let key = trim (urldecode key) and value = trim (urldecode value) in
	if key = "" then None else Some (key, value) 
    with 
    | (SyntaxError _ as exn) -> raise exn
    | exn -> Some (pair, "") 
      
let parse_params params = 
  let pairs = String.nsplit params "&" in
  List.to_map fst snd (List.filter_map parse_param pairs) 

let parse config ssl_socket =   

  let! head, body = read_request config ssl_socket in 

  (* Extract the main bits of information from the socket. *)

  let verb, uri, params, version, headers, body, ip = 
    let first_line, headers = String.split head "\r\n" in
    let verb, rest = String.split first_line " " in
    let uri, version = String.split rest " " in
    let ip = ip ssl_socket in 
    let uri, params = try String.split uri "?" with _ -> uri, "" in 
    verb, uri, params, version, parse_headers headers, body, ip 
  in  

  (* Start extracting individual bits from the parsed values *)

  let params = parse_params params in 

  let host = try Map.find "HOST" headers with Not_found -> raise (SyntaxError "Expected Host: header") in
  
  let verb = match verb with 
    | "GET" -> `GET
    | "POST" -> `POST
    | "PUT" -> `PUT
    | "DELETE" -> `DELETE 
    | _ -> raise (NotImplemented verb)
  in

  let content_type = 
    try let header = Map.find "CONTENT-TYPE" headers in
	(* TODO: break if non-UTF8 payload *)
	try Some (String.sub header 0 (String.index header ';'))
	with Not_found -> Some header	  
    with Not_found -> None 
  in
  
  let path = List.map urldecode (List.filter (fun s -> s <> "") (String.nsplit uri "/")) in 

  let token = 
    try let header = Map.find "AUTHORIZATION" headers in
	let prefix = "RUNORG token=" in
	if String.starts_with header prefix 
	then Some (Token.I.of_string (String.lchop ~n:(String.length prefix) header))
	else None
    with Not_found -> None 
  in

  let limit = 
    try Some (int_of_string (Map.find "limit" params)) 
    with Not_found -> None | _ -> raise (SyntaxError "Invalid limit parameter") in 

  let offset = 
    try Some (int_of_string (Map.find "offset" params)) 
    with Not_found -> None | _ -> raise (SyntaxError "Invalid offset parameter") in   

  let at = 
    try Some (Cqrs.Clock.of_json (Json.unserialize (Map.find "at" params))) 
    with Not_found -> None | _ -> raise (SyntaxError "Invalid at parameter") in   
  
  let accept = 
    try let list = String.nsplit (Map.find "ACCEPT" headers) "," in
	let list = List.map (fun s -> try fst (String.split s ";") with Not_found -> s) list in
	if List.mem "application/x-mempack" list then `MSGPACK else `JSON
    with Not_found -> `JSON
  in

  let body = 
    match body with None -> None | Some bytes ->
      match content_type with 
      | Some "application/json" -> 
	Some (`JSON (try Json.unserialize bytes with _ -> raise (SyntaxError "Invalid JSON")))
      | Some "application/x-msgpack" ->
	Some (`JSON (try Pack.of_string Json.unpack bytes with _ -> raise (SyntaxError "Invalid MSGPACK")))
      | _ -> Some (`Raw bytes)
  in

  (* Pack everything in an object *)

  let request = object
    method client_ip = ip 
    method host = host 
    method verb = verb
    method content_type = content_type
    method path = path
    method headers = headers 
    method params = params
    method token = token
    method at = at
    method limit = limit
    method offset = offset 
    method accept = accept
    method body = body
  end in

  if log_enabled then 
    Log.trace "Parsed: %s" (to_string request) ;

  return (request : t) 
      
