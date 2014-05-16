(* © 2013 RunOrg *)

open Std
open Common

module Ssl = SafeSsl

type error = 
  | HeaderTooLong
  | BodyTooLong
  | SyntaxError of string
  | NotImplemented of string
  | Timeout

type cors = string * (string, string) Map.t

(* Request parser logging 
   ====================== *)

let log_enabled = false

(* A parsed HTTP request
   ===================== *)

type t = <

  host : string ; 
  client_ip : IpAddress.t ; 
  path : string list ; 

  verb : [ `GET | `PUT | `POST | `DELETE | `OPTIONS ] ;
  body : [ `JSON of Json.t | `Raw of string ] option ;

  headers : (string, string) Map.t ;
  params : (string, string) Map.t ;

  token : Token.I.t option ;
  at : Cqrs.Clock.t option ;
  as_ : PId.t option ;  
  limit : int option ;
  offset : int option ; 

  content_type : string option ; 
  origin : string option ;

  accept: [ `JSON | `MSGPACK ] ;
> ;;

let to_string req = 
  !! "%s /%s" 
    (match req # verb with
    | `PUT -> "PUT"
    | `GET -> "GET"
    | `POST -> "POST"
    | `DELETE -> "DELETE"
    | `OPTIONS -> "OPTIONS") 
    (String.concat "/" req # path) 

(* Decoding functions 
   ================== *)

let decode_regexp = Str.regexp "%[0-9A-Za-z][0-9A-Za-z]"

exception DecodeChar of string

let decode_char sub = 
  try 
    let h = Char.base36_decode sub.[1] and l = Char.base36_decode sub.[2] in
    String.of_char (Char.chr (h * 16 + l))
  with _ -> 
    raise (DecodeChar sub)

let urldecode str = 

  let has_percent = ref false in 
  for i = 0 to String.length str - 1  do 
    match str.[i] with 
    | '+' -> str.[i] <- ' ' 
    | '%' -> has_percent := true 
    |  _  -> () 
  done ;

  if !has_percent then
    try 
      Ok (Str.global_substitute decode_regexp decode_char str)
    with 
      DecodeChar sub -> Bad (SyntaxError ("Could not url-decode " ^ sub))
  else
    Ok str

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

(* Most (if not all) sub-functions in read_request return an Std.result to handle
   errors. No exceptions are ever thrown. *)

let read_request config ssl_socket = 

  let timeout = Unix.gettimeofday () +. config.max_duration in 
  
  (* Read the entire header, plus any additional data after the end of the
     header. *)
  let read_header () = 
    let buffer = String.create 1024 in
    let header = Buffer.create 1024 in

    let rec more retries =       

      let l  = try Ok (Ssl.read ssl_socket buffer 0 1024) with 
	| Ssl.Read_error Ssl.Error_want_read -> Ok 0 
	| Ssl.Read_error Ssl.Error_syscall   -> 
	  let socket = Ssl.file_descr_of_socket ssl_socket in
	  ( match Unix.getsockopt_error socket with 
	    | None       -> Log.error "Ssl.read: Unexpected EOF." 
	    | Some error -> Log.error "Ssl.read: %s" (Unix.error_message error)) ;
	  Bad Timeout 
      in

      match l with Bad _ as e -> return e | Ok l -> 

	let () = Buffer.add_substring header buffer 0 l in

	if log_enabled then 
	  Log.trace "Read header %d (total %d/%d): \n%s" l (Buffer.length header) (config.max_header_size)
	    (String.sub buffer 0 l) ;

	if Buffer.length header = config.max_header_size then 
	  return (Bad HeaderTooLong) 
	else if String.exists (Buffer.contents header) "\r\n\r\n" then 
	  return (Ok ())
	else if l = 0 then 
	  let now = Unix.gettimeofday () in 
	  let delay = delay retries timeout now in 
	  if now > timeout then return (Bad Timeout) else 
	    let! () = Run.sleep delay in
	    more (retries + 1) 
	else 
	  more 0 

    in

    let! result = more 0 in
    match result with Bad _ as e -> return e | Ok () ->
 
      let header = Buffer.contents header in 
    
      (* Look for a header termination... *)
      let pos = try Ok (String.find header "\r\n\r\n") with _ -> Bad HeaderTooLong in 
      match pos with Bad _ as e -> return e | Ok pos ->  
      
	let clean_header = String.sub header 0 pos in 
	let body_start = 
	  if String.length header - pos <= 4 then "" else  
	    String.sub header (pos + 4) (String.length header - pos - 4)
	in 
	return (Ok (clean_header, body_start))

  in

  (* Read the entire body, up to the specified size, with a start size *)
  let read_body start size = 
    if size = 0 then return (Ok "") else 

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
	
	  if i = size then return (Ok ())
	  else if l = 0 then 
	    let now = Unix.gettimeofday () in 
	  if now > timeout then return (Bad Timeout) else 
	    let! () = Run.sleep (delay retries timeout now) in
	    more (retries + 1) i
	else
	  more retries i 

      in

      let! result = more 0 i in
      match result with Bad _ as e -> return e | Ok () -> 
      
	( if log_enabled then
	    Log.trace "Body:\n%s" body ;
	  
	  return (Ok body) )

  in
	  
  let! head = read_header () in     
  match head with Bad _ as e -> return e | Ok (header, body) -> 

  if expects_body header then begin 

    let size = expected_body_size header in 

    if log_enabled then 
      Log.trace "Expecting body of size %d" size ; 

    if size > config.max_body_size then return (Bad BodyTooLong) else 

      let! body = read_body body size in 
      match body with Bad _ as e -> return e | Ok body -> 
      
	return (Ok (header, Some body))

  end else
    
    ( if log_enabled then 
	Log.trace "No body expected" ; 
      
      return (Ok (header, None)) ) 
  
(* Request parsing
   =============== *)

(* Most (if not all) sub-functions in parse return an Std.result to handle
   errors. No exceptions are ever thrown. *)

let parse_header line = 
  let open String in 
  let line = trim line in
  if line = "" then Ok None else 
    try 
      let name, value = split line ":" in 
      Ok (Some ( trim (uppercase name), trim value ))
    with exn -> Bad (SyntaxError ("Invalid header: " ^ line))

let parse_headers headers = 
  let lines = String.nsplit headers "\r\n" in
  let parsed = List.map parse_header lines in 
  match List.filter_ok parsed with Bad _ as e -> e | Ok list ->  
    Ok (List.to_map fst snd (List.filter_map identity list)) 

let parse_param pair =
  if pair = "" then Ok None else
    let key, value = try String.split pair "=" with _ -> pair, "" in
    match urldecode key with Bad _ as e -> e | Ok key ->
      match urldecode value with Bad _ as e -> e | Ok value -> 
	let key = String.trim key and value = String.trim value in 
	if key = "" then Ok None else Ok (Some (key,value))
      
let parse_params params = 
  let pairs = String.nsplit params "&" in
  let parsed = List.map parse_param pairs in 
  match List.filter_ok parsed with Bad _ as e -> e | Ok list -> 
    Ok (List.to_map fst snd (List.filter_map identity list)) 

let parse_head head = 

  match try Ok (String.split head "\r\n") with _ -> Bad (SyntaxError "Invalid header") 
  with Bad _ as e -> e | Ok (first_line, headers) -> 

    match try Ok (String.split first_line " ") with _ -> Bad (SyntaxError "First line is invalid") 
    with Bad _ as e -> e | Ok (verb, rest) -> 

      match try Ok (String.split rest " ") with _ -> Bad (SyntaxError "First line is invalid") 
      with Bad _ as e -> e | Ok (uri, _) -> 

	let uri, params = try String.split uri "?" with _ -> uri, "" in 

	match parse_headers headers with Bad _ as e -> e | Ok headers -> 
	  
	  Ok (verb, uri, params, headers)

let parse_host headers = 
  try Ok (Map.find "HOST" headers) 
  with Not_found -> Bad (SyntaxError "Expected Host: header")

let parse_verb = function
  | "GET"     -> Ok `GET
  | "POST"    -> Ok `POST
  | "PUT"     -> Ok `PUT
  | "DELETE"  -> Ok `DELETE 
  | "OPTIONS" -> Ok `OPTIONS
  | verb      -> Bad (NotImplemented verb)

let parse_path uri =   
  String.nsplit uri "/"
  |> List.filter (fun s -> s <> "")
  |> List.map urldecode
  |> List.filter_ok 

let parse_int_param name params = 
  try Ok (Some (int_of_string (Map.find name params))) with 
  | Not_found -> Ok None 
  | _         -> Bad (SyntaxError ("Invalid "^name^" parameter")) 

let parse_as params = 
  try let cid = Map.find "as" params in
      match PId.of_string_checked cid with 
      | Some id -> Ok (Some id) 
      | None    -> Bad (SyntaxError (!! "'as' parameter is not a person id: '%s'" cid)) 
  with Not_found -> Ok None 

let parse_at params = 
  try Ok (Some (Cqrs.Clock.of_json (Json.unserialize (Map.find "at" params)))) with 
  | Not_found -> Ok None 
  | _         -> Bad (SyntaxError "Invalid at parameter") 

let parse_body body content_type = 
  match body with None -> Ok None | Some bytes ->
    match content_type with 
    | Some "application/json" -> begin
      try Ok (Some (`JSON (Json.unserialize bytes)))
      with _ -> Bad (SyntaxError "Invalid JSON")
    end
    | Some "application/x-msgpack" -> begin
      try Ok (Some (`JSON (Pack.of_string Json.unpack bytes)))
      with _ -> Bad (SyntaxError "Invalid MSGPACK")
    end
    | _ -> Ok (Some (`Raw bytes))

let parse config ssl_socket =   

  let! request = read_request config ssl_socket in 
  match request with Bad _ as e -> return (None,e) | Ok (head, body) -> 

  (* Extract the main bits of information from the socket. *)

  match parse_head head with Bad _ as e -> return (None,e) | Ok (verb, uri, params, headers) -> 

    (* Grab the origin as fast as possible, so that failures are sent with the
       correct CORS response headers. *)

    let origin = try Some (Map.find "ORIGIN" headers) with Not_found -> None in
    let cors = match origin with None -> None | Some origin -> Some (origin, headers) in
    let fail e = return (cors, e) in

    (* Extract data for which parsing can not fail. *)

    let ip = ip ssl_socket in       
    
    let content_type = 
      try let header = Map.find "CONTENT-TYPE" headers in
	  (* TODO: break if non-UTF8 payload *)
	  try Some (String.sub header 0 (String.index header ';'))
	  with Not_found -> Some header	  
      with Not_found -> None 
    in

    let token = 
      try let header = Map.find "AUTHORIZATION" headers in
	  let prefix = "RUNORG token=" in
	  if String.starts_with header prefix 
	  then Some (Token.I.of_string (String.lchop ~n:(String.length prefix) header))
	  else None
      with Not_found -> None 
    in

    let accept = 
      try let list = String.nsplit (Map.find "ACCEPT" headers) "," in
	  let list = List.map (fun s -> try fst (String.split s ";") with Not_found -> s) list in
	  if List.mem "application/x-mempack" list then `MSGPACK else `JSON
      with Not_found -> `JSON
    in

    (* Extract data for which parsing could fail. *)
    
    match parse_params params             with Bad _ as e -> fail e | Ok params -> 
    match parse_host headers              with Bad _ as e -> fail e | Ok host -> 
    match parse_verb verb                 with Bad _ as e -> fail e | Ok verb -> 
    match parse_path uri                  with Bad _ as e -> fail e | Ok path -> 	 
    match parse_int_param "limit" params  with Bad _ as e -> fail e | Ok limit ->
    match parse_int_param "offset" params with Bad _ as e -> fail e | Ok offset -> 
    match parse_as params                 with Bad _ as e -> fail e | Ok as_ ->
    match parse_at params                 with Bad _ as e -> fail e | Ok at -> 
    match parse_body body content_type    with Bad _ as e -> fail e | Ok body -> 

      (* Pack everything in an object *)

      let request : t = object
	method client_ip    = ip 
	method host         = host 
	method verb         = verb
	method content_type = content_type
	method origin       = origin
	method path         = path
	method headers      = headers 
	method params       = params
	method token        = token
	method at           = at
	method as_          = as_
	method limit        = limit
	method offset       = offset 
	method accept       = accept
	method body         = body
      end in
      
      if log_enabled then 
	Log.trace "Parsed: %s" (to_string request) ;
      
      return (cors, Ok request) 
      
