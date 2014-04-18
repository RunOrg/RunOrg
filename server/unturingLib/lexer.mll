{
  (* © 2014 RunOrg *)

  open Std
  open Parser
  open Lexing

  exception UnknownToken of char

  let string_of_token = function 
    | Int       i  -> string_of_int i 
    | Inline (i,_) -> !! "$%d" i
    | Name      n  -> n
    | Semicolon    -> ";"
    | BracketO     -> "["
    | BracketC     -> "]"
    | Dot          -> "."
    | EOF          -> "<end-of-script>"  
}

let wsp = [ ' ' '\t' ] *
let id = [ 'a' - 'z' 'A' - 'Z' '_' ] [ 'a' - 'z' 'A' - 'Z' '_' '0' - '9' ] *
let int = '0' | (['1' - '9'] ['0' - '9'] *) 

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

  | id as s { Name s }
  | _  as c { raise (UnknownToken c) }
