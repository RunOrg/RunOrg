(* © 2014 RunOrg *)

(** Pervasives file. Includes relevant functions and modules. *)

(* All pervasive values from Batteries are available by default. *)
include BatPervasives

(* Extend the char module from batteries with a few helper functions. *)
module Char = struct

  include BatChar

  (** Parses a case-insensitive digit in base 36 and returns the corresponding 
      integer value. *)
  let base36_decode = function
    | ('0' .. '9') as c -> code c - code '0' 
    | ('a' .. 'z') as c -> 10 + (code c - code 'a')
    | ('A' .. 'Z') as c -> 10 + (code c - code 'A')
    | _ -> 0

  (** Parses a case-sensitive digit in base 62 and returns the corresponding
      integer value. *)
  let base62_decode = function
    | ('0' .. '9') as c -> code c - code '0' 
    | ('A' .. 'Z') as c -> 10 + (code c - code 'A')
    | ('a' .. 'z') as c -> 36 + (code c - code 'a')
    | _ -> 0

  (** Encodes an integer in range [0..61] as a character in base 62. *)
  let base62_encode =
    let chars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz" in
    fun i -> chars.[i]
    
end

(* Extend the string module from Batteries with a few helper functions. *)
module String = struct

  include BatString

  (** Replace all typical french accents with their non-accented letter counterparts. *)
  let fold_accents str = 
    List.fold_left (fun str (reg,rep) -> Str.global_replace (Str.regexp reg) rep str) str
      [ "à\\|À\\|â\\|Â\\|ä\\|Ä"         , "a" ;
	"é\\|É\\|ê\\|Ê\\|è\\|È\\|ë\\|Ë" , "e" ; 
	"ç\\|Ç"                         , "c" ;
	"î\\|Î\\|ï\\|Ï"                 , "i" ;
	"ù\\|Ù\\|û\\|Û\\|ü\\|Ü"         , "u" ;
	"ô\\|Ô\\|ö\\|Ö"                 , "o" ;
	"œ\\|Œ"                         , "oe" ;
      ]

  (** Remove an UTF-8 byte order mark at the beginning of a string *)
  let remove_bom str = 
    if BatString.starts_with str "\239\187\191" then String.sub str 3 (String.length str - 3)
    else str
      
  (** Clip an UTF-8 string after the specified number of bytes. Does not cut
      in the middle of a multi-byte character. *)
  let clip size str = 
    let len = String.length str in 
    if len <= size then str else
      let rec cut i = 
	if i = len then str else 
	  let code = Char.code str.[i] in
	  if 0 <> code land 0x80 then cut (i+1) else String.sub str 0 i 
      in cut size 

  (** Replace all french accents with their non-accented counterparts, and converts
      all letters to uppercase. *)
  let fold_all str = 
    trim (uppercase (fold_accents (remove_bom str)))

  (** Replace every occurrence of a substring by another. *)
  let replace_all ~pattern ~by str = 
    concat by (nsplit str pattern)

  (** Pseudo-encode a byte sequence in base62. This is not an actual base change. 
      Rather, individual sequences of 32 bits are turned into their corresponding
      base62 representation. *)
  let base62_encode bytes = 
    let n_blocks = (length bytes / 4) + (if (length bytes) mod 4 = 0 then 0 else 1) in
    let output = String.create (n_blocks * 6) in
    let i62 = Int64.of_int 62 in
    for i = 0 to n_blocks - 1 do 
      let n = ref Int64.zero in
      for j = 3 downto 0 do
	n := Int64.add 
	  (Int64.shift_left !n 8) 
	  (Int64.of_int (if (i * 4 + j >= length bytes) then 0 else Char.code (bytes.[i * 4 + j]))) 
      done ;
      for j = 0 to 5 do 
	let c = Int64.to_int (Int64.rem !n i62) in
	n := Int64.div !n i62 ;
	output.[i * 6 + j] <- Char.base62_encode c
      done
    done ;
    output

  module Label = StdLib.Label
  module Rich = StdLib.Rich
    
end

module Map = BatMap

(* Extend the option module from batteries with a few helper functions. *)
module Option = struct
    
  include BatOption
  module M = Run.ForOption

  (** [first_or_default list def] return the first [Some] element in [list], 
      or [def]. *)
  let rec first_or_default l d = 
    match l with 
    | [] -> d 
    | Some h :: _ -> h 
    | None :: t -> first_or_default t d

end

(* Extend the list module from Batteries with a few helper functions. *)
module List = struct

  include BatList
  module M = Run.ForList
    
  (** Returns the last element of a list, [None] for an empty list. *)
  let rec last = function
    | []   -> None
    | [x]  -> Some x
    | _::t -> last t
      
  (** Returns the first element of a list, [None] for an empty list. *)
  let first = function
    | []   -> None
    | h::_ -> Some h

  (** Numbers the elements of a list. [number [a;b;c]] returns [0,a;1,b;2,c] *)
  let number list = 
    let rec aux acc = function
      | [] -> []
      | h :: t -> (acc , h) :: (aux (acc+1) t)
    in aux 0 list

  (** Creates a range list. [1 -- 7] return [[1;2;3;4;5;6]] *)
  let (--) a b = 
    let rec aux n = if n >= b then [] else n :: aux (n+1) in
    aux a

  (** Turns a list into a map. [to_map fk fv list] creates a binding [(fk x, fv x)] 
      for every item [x] of [list]. *)
  let to_map fk fv list = 
    List.fold_left (fun map x -> Map.add (fk x) (fv x) map) Map.empty list

  (** Turns a map into a list. For each binding [(k,v)] in the map, adds element
      [zip k v] to the list. The order is unspecified. *)
  let of_map zip map = 
    Map.foldi (fun k v list -> (zip k v) :: list) map []

end

(** Shorthand notation for [sprintf] *)
let (!!) = Printf.sprintf

(** Build comparison functions by projection. [by f a b] is equivalent to 
    [(fun a b -> compare (f a) (f b)] *)
let by f a b = compare (f a) (f b)

(** Clamp a value to an interval. [clamp vmin vmax x] is equivalent to 
    [min vmax (max vmin x)] *)
let clamp vmin vmax x = min vmax (max vmin x)

let return x = Run.return x

(* Include the SHA1 module with some minor extensions. *)
module Sha1 = struct

  include Sha1

  (** The number of bytes in a SHA1 hash. *)
  let bytes = 40
    
  (** Computes the SHA1 of a string and returns the hash as a sequence of 40 bytes. *)
  let hash_of_string str = 
    let hex = to_hex (string str) in
    let len = String.length hex in
    String.init (len/2) 
      (fun i -> Char.(chr (base36_decode hex.[2*i] * 16 + base36_decode hex.[2*i+1])))

  (** Computes a SHA1 HMAC from the provided key and plaintext. Returned as a sequence of
      40 bytes.*)
  let hmac key plaintext = 
    let len       = String.length key in
    let o_key_pad = String.init 64
      (fun i -> Char.chr ((if i < len then Char.code key.[i] else 0) lxor 0x5c)) in
    let i_key_pad = String.init 64 
      (fun i -> Char.chr ((if i < len then Char.code key.[i] else 0) lxor 0x36)) in
    hash_of_string (o_key_pad ^ hash_of_string (i_key_pad ^ plaintext))

end

(* Include the Ssl module with some minor extensions. *)
module Ssl = struct

  include Ssl 
    
  let trace_errors = false

  (** A string representing an [Ssl_error] *)
  let string_of_error = Ssl.(function 
    | Error_none -> "No error happened. This is never raised and should disappear in future versions."
    | Error_ssl -> "Error_ssl" 
    | Error_want_read -> "The read operation did not complete; the same TLS/SSL I/O function should be called again later."
    | Error_want_write -> "The write operation did not complete; the same TLS/SSL I/O function should be called again later."
    | Error_want_x509_lookup -> "The operation did not complete because an application callback set by [set_client_cert_cb] has asked to be called again.  The TLS/SSL I/O function should be called again later. Details depend on the application."
    | Error_syscall -> "Some I/O error occurred.  The OpenSSL error queue may contain more information on the error."
    | Error_zero_return -> "The TLS/SSL connection has been closed.  If the protocol version is SSL 3.0 or TLS 1.0, this result code is returned only if a closure alert has occurred in the protocol, i.e. if the connection has been closed cleanly. Note that in this case [Error_zero_return] does not necessarily indicate that the underlying transport has been closed."
    | Error_want_connect -> "The operation did not complete; the same TLS/SSL I/O function should be called again later."
    | Error_want_accept -> "The operation did not complete; the same TLS/SSL I/O function should be called again later..")

  (** A string representation (remote IP and port) of a socket. *)
  let string_of_socket socket = 
    let inner = Ssl.file_descr_of_socket socket in
    let peer = Unix.getpeername inner in 
    match peer with 
    | Unix.ADDR_UNIX str -> str
    | Unix.ADDR_INET (inet,port) -> !! "%s:%d" (Unix.string_of_inet_addr inet) port 

  let read = 
    if not trace_errors then read else
      fun socket buffer offset length -> 
	try read socket buffer offset length with 
	| (Ssl.Read_error inner) as exn -> 
	  Log.trace "Ssl.read(%s) : %s" (string_of_socket socket) (string_of_error inner) ; 
	  raise exn
	| exn -> 
	  Log.trace "Ssl.read(%s) : %s" (string_of_socket socket) (Printexc.to_string exn) ; 
	  raise exn 

  let output_string = 
    if not trace_errors then output_string else
      fun socket buffer -> 
	try output_string socket buffer with 
	| (Ssl.Write_error inner) as exn -> 
	  Log.trace "Ssl.output_string(%s) : %s" (string_of_socket socket) (string_of_error inner) ; 
	  raise exn
	| exn -> 
	  Log.trace "Ssl.output_string(%s) : %s" (string_of_socket socket) (Printexc.to_string exn) ; 
	  raise exn 
	  
end
