(* © 2013 RunOrg *)

type path = string list
type result = {
  root : string ; 
  i18n : (string * path list) list ;
  templates : path list ;
  javascript : path list ; 
  css : path list ; 
}

(* A string representation of a result. *)
let to_string result = 
  String.concat "" [
    "in: " ; 
    result.root ; 
    "\ni18n:\n  " ;
    String.concat "\n  " (List.map (fun (lang, paths) ->
      lang ^ ":\n    " ^
	String.concat "\n    " (List.map (String.concat "/") paths)) result.i18n) ;       
    "\ntemplates:\n  " ;
    String.concat "\n  " (List.map (String.concat "/") result.templates) ;
    "\njavascript:\n  " ;
    String.concat "\n  " (List.map (String.concat "/") result.javascript) ;
    "\ncss:\n  " ;
    String.concat "\n  " (List.map (String.concat "/") result.css) ; 
  ]

(* An empty result. *)
let empty root = { root ; i18n = [] ; templates = [] ; javascript = [] ; css = [] }

(* Extract the language name from an i18n file name. *)
let language_of_i18n_filename filename = 
  Filename.chop_suffix filename ".i18n.js"

(* Get the basename of a path. *)
let rec filename = function 
  | [] -> failwith "No file name in empty path"
  | [ basename ] -> basename
  | _ :: tail -> filename tail 

(* Read the contents of a directory, returned as a list. *)
let read_dir path = 
  try let list = List.sort compare (Array.to_list (Sys.readdir path))  in
      List.iter print_endline list ;
      list 
  with exn -> 
    print_endline 
      (Printf.sprintf "While reading directory %S:\n%s" path 
	 (Printexc.to_string exn)) ;
    exit (-1)

(* Returns true if the path (which must exist) is a directory. *)
let is_directory path = 
  try Sys.is_directory path 
  with exn -> 
    print_endline 
      (Printf.sprintf "While testing if %S is a directory:\n%s" path 
	 (Printexc.to_string exn)) ;
    exit (-1)
      
(* Iterate over all files in a directory. The directory 
   function is passed the path, the basename, and the 
   accumulator. *)
let fold_all_files f path acc = 
  
  (* The prefix is a *reverse* path. *)
  let rec fold prefix path acc =     
    List.fold_left (fun acc name ->
      let path = Filename.concat path name in 
      if is_directory path then
	fold (name :: prefix) path acc
      else
	f (List.rev (name :: prefix)) name acc 
    ) acc (List.rev (read_dir path))
  in
  
  fold [] path acc

(* Add a new i18n file to a result. *)
let add_i18n path filename result = 
  { result with i18n = (
    let language = language_of_i18n_filename filename in 
    try let list = List.assoc language result.i18n in 
	(language, path :: list) :: (List.remove_assoc language result.i18n)
    with Not_found -> (language, [path]) :: result.i18n
  )}

(* Does a file name end with one of the specified extensions ? *)
let has_extension filename extensions = 
  let len = String.length filename in 
  List.exists 
    (fun ext -> 
      let extlen = String.length ext in 
      extlen < len &&
	String.lowercase (String.sub filename (len - extlen) extlen) = ext)
    extensions

(* Building the result from provided paths and filenames *)
let build_result path filename result = 
  if has_extension filename [".htm";".html"] then
    { result with templates = path :: result.templates }
  else if has_extension filename [".i18n.js"] then
    add_i18n path filename result
  else if has_extension filename [".js"] then
    { result with javascript = path :: result.javascript }
  else if has_extension filename [".css"] then
    { result with css = path :: result.css }
  else
    result

(* Explore a directory. *)
let explore path = 
  fold_all_files build_result path (empty path)
