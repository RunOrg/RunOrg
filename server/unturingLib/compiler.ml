(* © 2014 RunOrg *)

open Std

type script = Ast.t 

let compile str inline = 

  let inline = Array.of_list inline in 
  let inline x = if x > Array.length inline || x < 1 then Json.Null else inline.(x - 1) in

  let lexbuf = Lexing.from_string str in 
  let token  = Lexer.token inline in 

  let last () = Lexing.(
    let b = lexbuf.lex_start_p.pos_cnum in
    let l = lexbuf.lex_curr_p.pos_cnum - b in
    String.sub str b l) in

  let syntax s = 
    let line = Lexing.(lexbuf.lex_start_p.pos_lnum) in
    let char = Lexing.(lexbuf.lex_start_p.pos_cnum - lexbuf.lex_start_p.pos_bol) in
    `SyntaxError (s, line, char) 
  in

  try 
    let ast = Parser.script token lexbuf in 
    `OK ast
  with 
  | Lexer.UnknownToken c -> syntax (String.make 1 c)
  | Parsing.Parse_error  -> syntax (String.trim (last ()))
