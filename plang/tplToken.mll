{
  (* © 2013 RunOrg *)

  open TplParse

  (** Return the comparison operator that corresponds to the
      specified string. *)
  let comparison_of_string = function 
    | "=="  -> `Equal
    | "===" -> `TypeEqual
    | "<"   -> `Lt
    | "<="  -> `Leq
    | ">"   -> `Gt
    | ">="  -> `Geq
    | "!="  -> `NotEqual
    | "!==" -> `NotTypeEqual
    | _     -> assert false

  (** Unescape a literal string. *)
  let rec literal str = 
    (* This can be optimized *)
    match try Some (String.index str '\\') with Not_found -> None with 
    | None -> Literal str
    | Some i -> if i + 1 = String.length str then Literal str else 
	let c = match str.[i+1] with 
	  | 'n' -> '\n'
	  | 'b' -> '\b'
	  | 't' -> '\t'
	  |  c  ->  c in
	let s = String.create (String.length str - 1) in
	String.blit str 0 s 0 i ;
	s.[i] <- c ;
	String.blit str (i + 2) s (i + 1) (String.length str - i - 2) ;
	literal s

  (** Parse an integer *)
  let int i = 
    try Int (int_of_string i) with _ -> Int max_int

  (** String representation of a token *)
  let string_of_token = function
    | Html h -> "Html(" ^ (if String.length h > 10 then String.sub h 0 10 ^ "..." else h) ^ ")"
    | Block b -> "Block(" ^ b ^ ")" 
    | EndCall -> "EndCall"
    | BeginBlock -> "BeginBlock"
    | EndEcho -> "EndEcho"
    | EndId -> "EndId"
    | EndI18n -> "EndI18n"
    | EndSub -> "EndSub"
    | Eof -> "Eof"
    | BeginEcho -> "BeginEcho"
    | BeginId -> "BeginId"
    | BeginI18n -> "BeginI18n"
    | BeginSub -> "BeginSub"
    | BeginCall -> "BeginCall"
    | Literal l -> "Literal(" ^ l ^ ")"
    | Int i -> "Int(" ^ string_of_int i ^ ")"
    | Name n -> "Name(" ^ n ^ ")"
    | Comparison _ -> "Comparison"
    | And -> "And"
    | Or -> "Or"
    | Not -> "Not"
    | Self -> "Self"
    | OpenBracket -> "OpenBracket"
    | CloseBracket -> "CloseBracket"
    | OpenParen -> "OpenParen"
    | CloseParen -> "CloseParen"
    | Dot -> "Dot"

}

let wsp = [ ' ' '\t' ] * 
let comparison = "==" | "===" | "<" | "<=" | ">" | ">=" | "!=" | "!=="
let ident = [ 'a' - 'z' 'A' - 'z' '_' ] [ 'a' - 'z' 'A' - 'Z' '_' '0' - '9' ] * 

rule file = parse
  | [^ '{' ] + as html { Html html }
  | '{' wsp (ident as name) wsp '}' { Block name }
  | "{>}" { EndCall }
  | "{{" { BeginEcho }
  | "{:" { BeginI18n }
  | "{(" { BeginSub }
  | "{<" { BeginCall }
  | "{$" { BeginId }
  | eof { Eof }

and expr = parse
  | wsp { expr lexbuf }
  | '\n' { expr lexbuf }	
  | '"' ( [ ^ '"' '\\' '\n' ] | '\\' [ ^ '\n' ] ) * as str '"' { literal str }
  | ('0' | '-' ? ['1' - '9'] [ '0' - '9' ] *) as i { int i }
  | comparison as c { Comparison (comparison_of_string c) } 
  | '}' { BeginBlock }
  | "}}" { EndEcho }
  | ":}" { EndI18n }
  | ">}" { EndCall }
  | ")}" { EndSub }
  | "$}" { EndId }
  | ident as name { Name name }
  | '.' { Dot }
  | '@' { Self }
  | '[' { OpenBracket }
  | ']' { CloseBracket }
  | "&&" { And }
  | "||" { Or }
  | '!' { Not }
  | '(' { OpenParen }
  | ')' { CloseParen }
  | eof { Eof }

{  

  let make () =
    let state = ref file in 
    fun lexbuf -> 
      let token = (!state) lexbuf in 
      state := (match token with 
        | Html _ 
	| Block _ 
	| EndCall
	| BeginBlock
	| EndEcho
	| EndId
	| EndI18n
	| EndSub 
	| Eof -> file

	| BeginEcho
	| BeginId
	| BeginI18n
	| BeginSub
	| BeginCall
	| Literal _
	| Int _
	| Name _
	| Comparison _
	| And
	| Or
	| Not
	| Self
	| OpenBracket
	| CloseBracket
	| OpenParen
	| CloseParen
	| Dot -> expr) ;
      token
	
}
