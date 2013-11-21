(* © 2013 RunOrg *)

open Std

let is_alphanumeric = 
  let regexp = Str.regexp "^[a-zA-Z0-9_]+$" in
  fun name -> Str.string_match regexp name 0

(* Stream names 
   ============ *)

let streams = Hashtbl.create 10

let stream name = 

  if Hashtbl.mem streams name then 
    failwith ("A stream named '" ^ name ^ "' already exists") ;

  if not (is_alphanumeric name) then 
    failwith ("Invalid stream name '" ^ name ^ "'") ;

  Hashtbl.add streams name () ;
  "stream:" ^ name

(* Projection prefixes
   =================== *)

type prefix = string option * (Common.ctx, string) Run.t

let projections = Hashtbl.create 10

let projection_prefix name version = 

  if Hashtbl.mem projections name then 
    failwith ("A projection named '" ^ name ^ "' already exists") ;

  if not (is_alphanumeric name) then 
    failwith ("Invalid projection name '" ^ name ^ "'") ;

  Hashtbl.add projections name version ;
  (  (Some name), 
     let! version = version in 
     Run.return (":" ^ name ^ "[" ^ string_of_int version ^ "].") )

(* Map names 
   ========= *)
    
let views = Hashtbl.create 10 

let view ?(prefix=(None, Run.return ":")) name version = 

  let surname  = match fst prefix with None -> name | Some p -> p ^ "." ^ name in

  if version < 0 then 
    failwith ("For view '" ^ surname ^ "': versions should be positive" ) ;
  
  if Hashtbl.mem views surname then 
    failwith ("A view named '" ^ surname ^ "' already exists") ;

  if not (is_alphanumeric name) then
    failwith ("Invalid view name '" ^ surname ^ "'") ;

  Hashtbl.add views surname () ;
  
  ( let! prefix = snd prefix in 
    Run.return ("view" ^ prefix ^ name ^ ":" ^ string_of_int version) )

let independent name version = 

  if version < 0 then 
    failwith ("For view '" ^ name ^ "': versions should be positive" ) ;
  
  if Hashtbl.mem views name then 
    failwith ("A view named '" ^ name ^ "' already exists") ;

  if not (is_alphanumeric name) then
    failwith ("Invalid view name '" ^ name ^ "'") ;

  Hashtbl.add views name () ;
  
  "view:" ^ name ^ ":" ^ string_of_int version
  
(* Version identifier generation 
   ============================= *)

let version () = 

  let open Hashtbl in 

  let  proj = fold (fun n v l -> (n,v) :: l) projections [] in
  let! proj = List.M.map 
    (fun (n,v) -> let! v = v in Run.return ("proj:" ^ n ^ "[" ^ string_of_int v ^ "]")) proj in 
    
  let names = List.fold_left (fun acc f -> f acc) proj [
    fold (fun n () l -> ("stream:" ^ n) :: l) streams ; 
    fold (fun n () l -> ("view:" ^ n) :: l) views ;    
  ] in

  let names = List.sort compare names in 
  let blob = String.concat ";" names in 

  Run.return (Sha1.to_hex (Sha1.string blob))
