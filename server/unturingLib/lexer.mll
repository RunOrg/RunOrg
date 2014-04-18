{
  (* © 2014 RunOrg *)

  open Std
  open Parser
  open Lexing

  exception UnknownToken of int * int * char

  let string_of_token = function 
    | Int       i  -> string_of_int i 
    | Inline (i,_) -> !! "$%d" (i + 1)
    | Name      n  -> n
    | Semicolon    -> ";"
    | BracketO     -> "["
    | BracketC     -> "]"
    | Dot          -> "."
    | This         -> "this"
    | EOF          -> "<end-of-script>"  
}

let wsp = [ ' ' '\t' ] *
let id = [ 'a' - 'z' 'A' - 'Z' '_' ] [ 'a' - 'z' 'A' - 'Z' '_' '0' - '9' ] *
let int = ['1' - '9'] ['0' - '9'] * 

rule token inline = parse

  | '\n' { new_line lexbuf ; token inline lexbuf }   
  | wsp  { token inline lexbuf }
  | '.'  { Dot }
  | ';'  { Semicolon }
  | '['  { BracketO }
  | ']'  { BracketC }
  | eof  { EOF }

  | '$' (int as i) { let i = int_of_string i in 
		     Inline (i, inline i) }

  | id as s { if s = "this" then This else Name s }
  | _  as c { let p = lexbuf.lex_start_p in
	      raise (UnknownToken (p.pos_lnum, p.pos_cnum-p.pos_bol, c)) }   
