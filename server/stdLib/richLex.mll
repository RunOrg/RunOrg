{
  (* © 2014 RunOrg *)

  open RichParse
  open RichParse.Token

  let (++) pos text = 
    let n = String.length text in 
    let rec add acc i = 
      if i > n then raise (ParseError (!pos + acc, "Invalid UTF8"))
      else if i = n then pos := !pos + i else
	let code = Char.code text.[i] in 
	if code < 0x70 then add (acc + 1) (i + 1) 
	else if code < 0xA0 then raise (ParseError (!pos + acc, "Invalid UTF8")) 
	else if code < 0xE0 then add (acc + 1) (i + 2)
	else if code < 0xF0 then add (acc + 1) (i + 3) 
	else add (acc + 1) (i + 4)
    in
    add 0 0 
}

let wsp = [ ' ' '\t' '\r' '\n' ] +

rule block pos = parse
  | [^ '&' '<' '>'] + as text { pos ++ text ; Text text }
  | "&amp;" { pos ++ "&amp;" ; Text "&" }
  | "&lt;" { pos ++ "&lt;" ; Text "<" }
  | "&gt;" { pos ++ "&gt;" ; Text ">" }
  | "&quot;" { pos ++ "&quot;" ; Text "\"" }
  | "</" (['a' - 'z' 'A' - 'Z'] ['a' - 'z' 'A' - 'Z' '0' - '9'] *) as tag '>' 
      { pos ++ ("</" ^ tag ^ ">") ; Close (String.lowercase tag) }
  | '<'(['a' - 'z' 'A' - 'Z'] ['a' - 'z' 'A' - 'Z' '0' - '9'] *) as tag 
      { pos ++ ("<" ^ tag) ; Open (String.lowercase tag, attrs pos lexbuf) }
  | '&' ('#' ? ['a' - 'z' 'A' - 'Z' '0' - '9'] *) as entity 
      { if entity = "" then raise (ParseError (!pos,"Unescaped & found")) 
	else raise (ParseError (!pos, "Unsupported entity code &" ^ entity ^ ";")) }
  | '<' { raise (ParseError (!pos, "Unescaped < found")) }
  | '>' { raise (ParseError (!pos, "Unescaped > found")) }
  | eof { Eof }

and attrs pos = parse 
  | wsp as w { pos ++ w ; attrs pos lexbuf }
  | '>' { [] }
  | (['a' - 'z' 'A' - 'Z'] ['a' - 'z' 'A' - 'Z' '0' - '9'] *) as name '=' '"'
      { let buf = Buffer.create 10 in
	pos ++ (name ^ "=\"") ; 	
	content buf pos lexbuf ; 
	(name, Buffer.contents buf) :: attrs pos lexbuf }
  | ['a' - 'z' 'A' - 'Z'] { raise (ParseError (!pos, "Invalid attribute syntax")) }
  | _ as c { raise (ParseError (!pos, Printf.sprintf "Unexpected character %c in tag" c)) }
  | eof { raise (ParseError (!pos, "Text ended prematurely (in opening tag)")) }
									  
and content buf pos = parse
  | [^ '&' '"'] + as text { pos ++ text ; Buffer.add_string buf text ; content buf pos lexbuf }
  | "&amp;" { pos ++ "&amp;" ; Buffer.add_char buf '&' ; content buf pos lexbuf }
  | "&lt;" { pos ++ "&lt;" ; Buffer.add_char buf '<' ; content buf pos lexbuf }
  | "&gt;" { pos ++ "&gt;" ; Buffer.add_char buf '>' ; content buf pos lexbuf }
  | "&quot;" { pos ++ "&quot;" ; Buffer.add_char buf '"' ; content buf pos lexbuf }
  | '&' ('#' ? ['a' - 'z' 'A' - 'Z' '0' - '9'] *) as entity 
      { if entity = "" then raise (ParseError (!pos, "Unescaped & found")) 
	else raise (ParseError (!pos, "Unsupported entity code &" ^ entity ^ ";")) }
  | '"' { pos ++ "\"" }
  | eof { raise (ParseError (!pos, "Text ended prematurely (in attribute value)")) }
