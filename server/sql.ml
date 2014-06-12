(* © 2014 RunOrg *)

open Std

type query = 

  (* A piece of raw query string with no parameters. *)
  | Raw of string

  (* A quoted identifier. *)
  | Escaped of string 

  (* Imploding a list of queries. *)
  | Implode of query list * query

  (* Concatenating a list of queries. *)
  | Concat of query list

  (* A string parameter. *)
  | String of int * string

  (* A binary parameter. *)
  | Binary of int * string

type scalar = query
type vector = query

(* Constructors 
   ============ *)

let uid = 
  let current = ref 0 in
  fun () -> incr current ; !current

let query = Raw ""
let q s = Raw s
let e s = Escaped s
let implode sep list = Implode (list, sep)  
let concat list = Concat list

let i int = Raw (string_of_int int)
let s str = String (uid (), str)
let pack packer value = Binary (uid (), Pack.to_string packer value)
let id id = s (Id.to_string id) 

let l f list = Concat [
  Raw "(" ;
  Implode (List.map f list, Raw ",") ;
  Raw ")" ;
]

let sub q = Concat [
  Raw "(" ;
  q ;
  Raw ")" ;
]

(* Compiling 
   ========= *)

(* Gives consecutive, one-indexed numbers to each parameter. 
   Returns the renumbered query and the number of parameters. *)
let renumber query = 

  let mapref = ref Map.empty in 

  let num n = 
    try Map.find n !mapref with Not_found ->
      let n' = 1 + Map.cardinal !mapref in 
      mapref := Map.add n n' !mapref ;
      n'
  in

  let rec aux = function 
    | Raw     _ as k -> k 
    | Escaped _ as k -> k 
    | Implode (l,s) -> Implode (List.map aux l, aux s)
    | Concat l -> Concat (List.map aux l) 
    | String  (n,s) -> String (num n, s)
    | Binary  (n,b) -> Binary (num n, b)
  in

  let renumbered = aux query in 
  renumbered, Map.cardinal !mapref 

let rec size = function
  | Raw     s -> String.length s
  | Escaped s -> 2 + String.length s 		 
  | Implode (l, s) -> let ssize = size s in 
		      let size = List.fold_left (fun acc q -> acc + size q + ssize) 0 l in 
		      if size > 0 then size - ssize else size
  | Concat list -> List.fold_left (fun acc q -> acc + size q) 0 list
  | String (n,_)
  | Binary (n,_) -> if n < 10 then 2 else
                    if n < 100 then 3 else
		    if n < 1000 then 4 else 5

let compile query =
 
  let query, numP = renumber query in

  (* Construct the query in a buffer. *)
  let buffer  = String.create (size query) in

  let i = ref 0 in 
  let addC c = buffer.[!i] <- c ; incr i in
  let addS s = let l = String.length s in String.blit s 0 buffer !i l ; i := !i + l in
  let addI i = if i < 10 then addC (Char.chr (i + 48)) else addS (string_of_int i) in

  let rec aux = function 
    | Raw s -> addS s
    | Escaped s -> addC '"' ; addS s ; addC '"' 
    | Implode (l, s) -> ignore (List.fold_left (fun sep q -> if sep then aux s ; aux q ; true) false l : bool)
    | Concat       l -> List.iter aux l 
    | String  (n, _)
    | Binary  (n, _) -> addC '$' ; addI n
  in

  aux query ;

  (* Build up the parameter arrays. *)
  let params  = Array.make numP "" in
  let paramsB = Array.make numP false in

  let rec extract = function 
    | Raw     _
    | Escaped _ -> () 
    | Implode (l,s) -> List.iter extract l ; extract s
    | Concat l -> List.iter extract l
    | String (n,s) -> params.(n-1) <- s
    | Binary (n,s) -> params.(n-1) <- s ; paramsB.(n-1) <- true
  in

  extract query ; 

  (buffer, params, paramsB) 
