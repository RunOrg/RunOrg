(* © 2014 RunOrg *)

open Std

include type module 
  | Local of string
  | IPv4  of string
  | IPv6  of string

(* Parsing addresses 
   ================= *)

let make_ipv4 port a b c d = 
  let str = String.create 6 in
  str.[0] <- Char.chr a ;
  str.[1] <- Char.chr b ;
  str.[2] <- Char.chr c ;
  str.[3] <- Char.chr d ;
  str.[4] <- Char.chr (port mod 256) ;
  str.[5] <- Char.chr (port / 256) ;
  IPv4 str

let make_ipv6 port a b c d e f g h = 
  let str = String.create 16 in
  str.[ 0] <- Char.chr (a mod 256) ;
  str.[ 1] <- Char.chr (a / 256) ;
  str.[ 2] <- Char.chr (b mod 256) ;
  str.[ 3] <- Char.chr (b / 256) ;
  str.[ 4] <- Char.chr (c mod 256) ;
  str.[ 5] <- Char.chr (c / 256) ;
  str.[ 6] <- Char.chr (d mod 256) ;
  str.[ 7] <- Char.chr (d / 256) ;
  str.[ 8] <- Char.chr (e mod 256) ;
  str.[ 9] <- Char.chr (e / 256) ;
  str.[10] <- Char.chr (f mod 256) ;
  str.[11] <- Char.chr (f / 256) ;
  str.[12] <- Char.chr (g mod 256) ;
  str.[13] <- Char.chr (g / 256) ;
  str.[14] <- Char.chr (h mod 256) ; 
  str.[15] <- Char.chr (h / 256) ;
  str.[16] <- Char.chr (port mod 256) ;
  str.[17] <- Char.chr (port / 256) ;
  IPv6 str

let inflate_ipv6 string = 
  let split   = String.nsplit string ":" in
  let count   = List.length split in
  let rec extend n = function 
    | l when n = 0 -> l 
    | h :: "" :: t -> h :: extend (n - 1) ("0" :: "" :: t) 
    | h :: t -> h :: extend (n - 1) t
    | [] -> "0" :: extend (n-1) [] 
  in
  let extended = extend (8 - count) split in 
  String.concat ":" (List.map (function "" -> "0" | n -> n) extended)

let parse string port = 
  try 
    Scanf.sscanf string "%u.%u.%u.%u" (make_ipv4 port)
  with _ -> 
    try 
      let string = inflate_ipv6 string in 
      Scanf.sscanf string "%x:%x:%x:%x:%x:%x:%x:%x" (make_ipv6 port)
    with _ -> 
      failwith ("Could not parse IP address '" ^ string ^ "'") 

let of_inet_addr addr port = 
  parse (Unix.string_of_inet_addr addr) port 

let of_sockaddr = function
  | Unix.ADDR_UNIX local -> Local local
  | Unix.ADDR_INET (addr,port) -> of_inet_addr addr port

(* Printing an IP address
   ====================== *)

let extract_ipv4 str = 
  let a = Char.code str.[0] in
  let b = Char.code str.[1] in
  let c = Char.code str.[2] in
  let d = Char.code str.[3] in
  let port = Char.code str.[4] + 256 * Char.code str.[5] in
  Printf.sprintf "%d.%d.%d.%d:%d" a b c d port 

let extract_ipv6 str = 
  let u16 i = Char.code str.[i] + 256 * Char.code str.[i+1] in
  let a = u16 0 in
  let b = u16 2 in
  let c = u16 4 in
  let d = u16 6 in
  let e = u16 8 in
  let f = u16 10 in
  let g = u16 12 in
  let h = u16 14 in
  let port = u16 16 in
  Printf.sprintf "[%x:%x:%x:%x:%x:%x:%x:%x]:%d" a b c d e f g h port 
 
let to_string = function 
  | Local local -> local
  | IPv4  bytes -> extract_ipv4 bytes
  | IPv6  bytes -> extract_ipv6 bytes

