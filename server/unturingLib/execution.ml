(* © 2014 RunOrg *)

open Std

type input = { 
  this : Json.t ;
  context : (string,Json.t) Map.t ;
}

(* Internal representation of values 
   ================================= *)

type value = 
  | Array  of value array
  | Map    of (string, value) Map.t
  | String of string
  | Html   of string
  | FlatL  of value list

let null = Html ""

let rec value_of_json ?(html=false) = function 
  | Json.Float  f -> String (string_of_float f)
  | Json.Int    i -> String (string_of_int i)
  | Json.Null     -> null
  | Json.String s -> if html then Html s else String s 
  | Json.Array  l -> Array (Array.of_list (List.map value_of_json l))
  | Json.Bool   b -> String (if b then "true" else "false")
  | Json.Object l -> Map (Map.of_list (List.map (fun (k,v) -> k, value_of_json v) l))

let escape buf s = 
  let open Buffer in 
  let b = ref 0 in
  let len = String.length s in
  for m = 0 to len - 1 do
    match s.[m] with
    | '<' -> let () = add_substring buf s !b (m - !b) in
	     let () = add_string buf "&lt;" in
	     b := m+1
    | '>' -> let () = add_substring buf s !b (m - !b) in
	     let () = add_string buf "&gt;" in
	     b := m+1
    | '&' -> let () = add_substring buf s !b (m - !b) in
	     let () = add_string buf "&amp;" in
	     b := m+1
    | '"' -> let () = add_substring buf s !b (m - !b) in
	     let () = add_string buf "&quot;" in
	     b := m+1
    | _ -> ()
  done ;
  if !b < len then
    add_substring buf s !b (len - !b)

let to_string ?(html=false) v =
  let b = Buffer.create 100 in
  let rec print = function
    | FlatL  l -> List.iter print l 
    | String s -> if html then escape b s else Buffer.add_string b s 
    | Html   s -> Buffer.add_string b s
    | Array  _ 
    | Map    _ -> () 
  in
  print v ; Buffer.contents b 
 
(* Executing the script on values 
   ============================== *)

let index i = function 
  | Array a when i >= 0 && i < Array.length a -> a.(i)
  | _ -> null

let member m = function 
  | Array a when m = "length" -> String (string_of_int (Array.length a))
  | Map   d -> (try Map.find m d with Not_found -> null)
  | _       -> null

let eval script input = 

  let rec eval = function 
    | Ast.Inline    j  -> value_of_json ~html:true j
    | Ast.This         -> value_of_json input.this
    | Ast.Context   s  -> (try value_of_json (Map.find s input.context) with Not_found -> null)
    | Ast.Flat      l  -> FlatL (List.map eval l)
    | Ast.Index  (e,i) -> index  i (eval e)
    | Ast.Member (e,m) -> member m (eval e)
  in

  eval script 

let template ~html script input = 
  to_string ~html (eval script input) 

(* Filtering input values 
   ====================== *)

let filter script input = 
  input 

