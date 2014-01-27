{
  (* © 2014 RunOrg *)

  open RichParse
  open RichParse.Token
}

let wsp = [ ' ' '\t' '\r' '\n' ]

rule block pos = parse
  | [^ '&' '<' '>'] + as text { Text text }
  | "&amp;" { Text "&" }
  | "&lt;" { Text "<" }
  | "&gt;" { Text ">" }
  | "&quot;" { Text "\"" }
  | "</" (['a' - 'z' 'A' - 'Z'] ['a' - 'z' 'A' - 'Z' '0' - '9'] *) as tag '>' 
      { Close (String.lowercase tag) }
  | '<'(['a' - 'z' 'A' - 'Z'] ['a' - 'z' 'A' - 'Z' '0' - '9'] *) as tag 
      { Open (String.lowercase tag, attrs pos lexbuf) }
  | '&' ('#' ? ['a' - 'z' 'A' - 'Z' '0' - '9'] *) as entity 
      { if entity = "" then raise (ParseError (!pos,"Unescaped & found")) 
	else raise (ParseError (!pos, "Unsupported entity code &" ^ entity ^ ";")) }
  | '<' { raise (ParseError (!pos, "Unescaped < found")) }
  | '>' { raise (ParseError (!pos, "Unescaped > found")) }
  | eof { Eof }

and attrs pos = parse 
  | wsp { attrs pos lexbuf }
  | '>' { [] }
  | ['a' - 'z' 'A' - 'Z'] ['a' - 'z' 'A' - 'Z' '0' - '9'] * '=' '"' as name 
      { let buf = Buffer.create 10 in
	content buf pos lexbuf ; 
	(name, Buffer.contents buf) :: attrs pos lexbuf }
  | ['a' - 'z' 'A' - 'Z'] { raise (ParseError (!pos, "Invalid attribute syntax")) }
  | _ as c { raise (ParseError (!pos, Printf.sprintf "Unexpected character %c in tag" c)) }
  | eof { raise (ParseError (!pos, "Text ended prematurely (in opening tag)")) }
									  
and content buf pos = parse
  | [^ '&' '"'] + as text { Buffer.add_string buf text ; content buf pos lexbuf }
  | "&amp;" { Buffer.add_char buf '&' ; content buf pos lexbuf }
  | "&lt;" { Buffer.add_char buf '<' ; content buf pos lexbuf }
  | "&gt;" { Buffer.add_char buf '>' ; content buf pos lexbuf }
  | "&quot;" { Buffer.add_char buf '"' ; content buf pos lexbuf }
  | '&' ('#' ? ['a' - 'z' 'A' - 'Z' '0' - '9'] *) as entity 
      { if entity = "" then raise (ParseError (!pos, "Unescaped & found")) 
	else raise (ParseError (!pos, "Unsupported entity code &" ^ entity ^ ";")) }
  | '"' { }
  | eof { raise (ParseError (!pos,"Text ended prematurely (in attribute value)")) }
