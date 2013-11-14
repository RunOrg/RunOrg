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
    
let maps = Hashtbl.create 10 

let map ?projection name version = 

  let prefix = match projection with 
    | Some p -> p # register "map" name version 
    | None -> (None, Run.return ":") in

  let surname  = match fst prefix with None -> name | Some p -> p ^ "." ^ name in

  if version < 0 then 
    failwith ("For map '" ^ surname ^ "': versions should be positive" ) ;
  
  if Hashtbl.mem maps surname then 
    failwith ("A map named '" ^ surname ^ "' already exists") ;

  if not (is_alphanumeric name) then
    failwith ("Invalid map name '" ^ surname ^ "'") ;

  Hashtbl.add maps surname () ;
  
  ( let! prefix = snd prefix in 
    Run.return ("map" ^ prefix ^ name) )

(* Version identifier generation 
   ============================= *)

let version () = 

  let open Hashtbl in 

  let  proj = fold (fun n v l -> (n,v) :: l) projections [] in
  let! proj = Run.list_map 
    (fun (n,v) -> let! v = v in Run.return ("proj:" ^ n ^ "[" ^ string_of_int v ^ "]")) proj in 
    
  let names = List.fold_left (fun acc f -> f acc) proj [
    fold (fun n () l -> ("stream:" ^ n) :: l) streams ; 
    fold (fun n () l -> ("map:" ^ n) :: l) maps ;    
  ] in

  let names = List.sort compare names in 
  let blob = String.concat ";" names in 

  Run.return (Sha1.to_hex (Sha1.string blob))
