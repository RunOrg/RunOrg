(* © 2013 RunOrg *)

type t = { 
  css  : string ;
  js   : string ; 
  i18n : (string * string) list ;
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
  let lexbuf = Lexing.from_string contents in 
  let token = TplToken.make () in 
  let ast = TplParse.file token lexbuf in
  path, ast 

let build ?(builtins = "./plang/builtins") explored = 

  let builtins = Explore.explore builtins in

  let scripts = 
    List.map (read_file builtins.Explore.root) builtins.Explore.javascript 
    @ List.map (read_file explored.Explore.root) explored.Explore.javascript in

  let templates = List.map (read_tpl_ast explored.Explore.root) explored.Explore.templates in 
  
  let i18n = 
    List.map 
      (fun (lang,files) -> lang, String.concat "" 
	("i18n.clear();" :: (List.map (read_file explored.Explore.root) files)))
      explored.Explore.i18n
  in

  let vars = [ 
    "TEMPLATES", TplGen.compile templates ;
  ] in
  
  { js = JsGen.compile scripts vars ; css = "" ; i18n }

