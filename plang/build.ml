(* © 2013 RunOrg *)

type t = { 
  css : string ;
  js  : string ; 
}

(* Read the contents of a file at the specified path relative to the 
   provided directory. *)
let read_file dir path = 
  let real_path = List.fold_left Filename.concat dir path in
  let chan = open_in real_path in 
  try 
    let length = in_channel_length chan in 
    let buffer = String.create length in
    really_input chan buffer 0 length ;
    close_in chan ;
    buffer
  with exn ->
    close_in chan ;
    raise exn 

(* Read and parse the contents of a template file, returns a 
   (path, ast) pair. *)
let read_tpl_ast dir path = 
  let contents = read_file dir path in 
  let lexbuf = Lexing.of_string contents in 
  let token = TplToken.make () in 
  let ast = TplParse.file token lexbuf in
  path, ast 

let build ?(builtins = "./plang/builtins") explored = 

  let open Explore in 

  let builtins = explore builtins in

  let scripts = 
    List.map (read_file builtins.root) builtins.javascript 
    :: List.map (read_file explored.root) explored.javascript in

  let templates = List.map (read_tpl_ast explored.root) explored.templates in 

  let vars = [ 
    "TEMPLATES", TplGen.compile templates ;
  ] in
  
  { js = JsGen.compile scripts vars ; css = "" }

