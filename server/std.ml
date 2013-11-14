(* © 2013 RunOrg *)

(** Pervasives file. Includes relevant functions and modules. *)

(* All pervasive values from Batteries are available by default. *)
include BatPervasives

(* Extend the string module from Batteries with a few helper functions. *)
module String = struct

  include BatString
  include Fmt.Make(struct type & t = string end)

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
	  if code land 0x80 then cut (i+1) else String.sub str i 
      in cut size 

  (** Replace all french accents with their non-accented counterparts, and converts
      all letters to uppercase. *)
  let fold_all str = 
    trim (uppercase (fold_accents (remove_bom str)))

  (** Replace every occurrence of a substring by another. *)
  let replace_all ~pattern ~by str = 
    concat by (nsplit str pattern)

end

module Map = BatMap

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

(* Extend the list module from Batteries with a few helper functions. *)
module List = struct

  include BatList
    
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

(* Include the SHA1 module with some minor extensions. *)
module Sha1 = struct

  include Sha1

  (** The number of bytes in a SHA1 hash. *)
  let bytes = 40
    
  (** Computes the SHA1 of a string and returns the hash as a sequence of 40 bytes. *)
  let hash_of_string str = 
    let hex = to_hex (string str) in
    let len = String.length hex in
    String.init (len/2) (fun i -> Char.(base36_decode hex.[2*i] * 16 + base36_decode hex.[2*i+1]))

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
