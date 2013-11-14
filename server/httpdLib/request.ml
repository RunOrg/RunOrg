(* © 2013 RunOrg *)

open Std
open Common

exception HeaderTooLong
exception BodyTooLong
exception SyntaxError of string
exception NotImplemented of string

(* A parsed HTTP request
   ===================== *)

type t = <

  host : string ; 
  client_ip : string ; 
  path : string list ; 

  verb : [ `GET | `PUT | `POST | `DELETE ] ;
  body : [ `JSON of Json.t | `Raw of string ] option ;

  headers : (string, string) Map.t ;
  params : (string, string) Map.t ;

  token : string option ;
  limit : int option ;
  offset : int option ; 

  content_type : string option ; 

  accept: [ `JSON | `MSGPACK ] ;
> ;;

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

(* Reading requests from sockets
   ============================= *)

let read_request config ssl_socket = 
  
  (* Read the entire header in one go. *)
  let header = String.create config.max_header_size in 
  let l = Ssl.read ssl_socket header 0 config.max_header_size in

  (* Look for a header termination... *)
  let pos = try String.find header "\r\n\r\n" with _ -> raise HeaderTooLong in
  let clean_header = String.sub header 0 pos in 

  (* A body is expected if the header starts with POST or PUT. *)
  if String.starts_with clean_header "POST" || String.starts_with clean_header "PUT" then begin

    let body = Buffer.create 1024 in
    let bufsize = 1024 in
    let buffer = String.create 1024 in

    let rec read_more () = 
      if Buffer.length body <= config.max_body_size then begin
	let l = Ssl.read ssl_socket buffer 0 bufsize in
	Buffer.add_substring body buffer 0 l ;
	if l = bufsize then read_more () 
      end
    in

    (* For some reason, there was a little bit of body at the end of the header... *)
    if l - pos > 4 then ( 
      Buffer.add_string body (String.sub header (pos + 4) (l - pos + 4)) ;
      if l = config.max_header_size then read_more ()) 
    else
      read_more () ;

    clean_header, Some (Buffer.contents body)

  end else
    
    clean_header, None

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

  (* Extract the main bits of information from the socket. *)

  let verb, uri, params, version, headers, body, ip = 
    let head, body = read_request config ssl_socket in 
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

  let content_type = try Some (Map.find "CONTENT-TYPE" headers) with Not_found -> None in
  
  let path = List.map urldecode (List.filter (fun s -> s <> "") (String.nsplit uri "/")) in 

  let token = try Some (Map.find "token" params) with Not_found -> None in

  let limit = 
    try Some (int_of_string (Map.find "limit" params)) 
    with Not_found -> None | _ -> raise (SyntaxError "Invalid limit parameter") in 

  let offset = 
    try Some (int_of_string (Map.find "offset" params)) 
    with Not_found -> None | _ -> raise (SyntaxError "Invalid offset parameter") in   
  
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

  (object
    method client_ip = ip 
    method host = host 
    method verb = verb
    method content_type = content_type
    method path = path
    method headers = headers 
    method params = params
    method token = token
    method limit = limit
    method offset = offset 
    method accept = accept
    method body = body
   end : t)
