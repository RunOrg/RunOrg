(* © 2014 RunOrg *)

(* Type definitions 
   ================ *)

module Token = struct
  type t = 
    | Text of string
    | Open of string * (string * string) list 
    | Close of string
    | Eof 
end

type inline = 
  | Text of string
  | Strong of inline list
  | Emphasis of inline list
  | Anchor of string * inline list

type block = 
  | Paragraph of inline list
  | UnorderedList of block list list
  | OrderedList of block list list
  | Blockquote of block list
  | Heading of int * inline list

type t = block list 

exception ParseError of int * string

(* The parsing entry point
   ======================= *)

let parse tok string = 

  let lexbuf = Lexing.from_string string in 
  let pos = ref 0 in 
  let tok = tok pos in 

  let error fmt = Printf.ksprintf (fun reason -> raise (ParseError (!pos, reason))) fmt in

  (* Recursive descent functions 
     =========================== *)

  let rec inline close acc (return : inline list -> Token.t -> 'a) = 
    let next r tok = inline close (r :: acc) return tok in 
    function 

      | Token.Eof       -> (match close with 
	                   | None -> return (List.rev acc) Token.Eof 
	                   | Some close -> error "Unexpected end of string in <%s>" close)

      | Token.Close tag -> (match close with
			   | Some close when tag = close -> return (List.rev acc) (tok lexbuf)    
			   | Some close -> error "Unexpected closing tag </%s> for <%s>" tag close
			   | None -> return (List.rev acc) (Token.Close tag))

      | Token.Text t -> next (Text t) (tok lexbuf) 

      | Token.Open ("strong",_) -> inline (Some "strong") [] (fun l -> next (Strong l)) (tok lexbuf) 
      | Token.Open ("em",_) -> inline (Some "em") [] (fun l -> next (Emphasis l)) (tok lexbuf) 

      | Token.Open ("a",attr) -> begin 
	try let href = List.assoc "href" attr in
	    let href = if BatString.starts_with href "javascript:" then "javascript:void(0)" else href in 
	    inline (Some "a") [] (fun l -> next (Anchor (href, l))) (tok lexbuf) 
	with Not_found -> error "Attribute 'href' expected in <a>"
      end 
	
      | Token.Open (tag,_) as tok -> if close = None then return (List.rev acc) tok 
                                     else error "Unexpected opening tag <%s>" tag
  in
  
  let rec block close acc (return : block list -> Token.t -> 'a) = 
    let next r tok = block close (r :: acc) return tok in
    function

      | Token.Eof            -> if close = None then return (List.rev acc) Token.Eof 
                               	else error "Unexpected end of string"

      | Token.Close tag      -> if close = Some tag then return (List.rev acc) (tok lexbuf) 
                                else error "Unexpected closing tag </%s>" tag

      | ( Token.Text _
        | Token.Open ("a",_)
	| Token.Open ("strong",_)
	| Token.Open ("em",_) ) as tok -> inline None [] (fun l -> next (Paragraph l)) tok

      | Token.Open ("p",_)   -> inline (Some "p") [] (fun l -> next (Paragraph l)) (tok lexbuf) 
      | Token.Open ("ul",_)  -> list "ul" [] (fun l -> next (UnorderedList l)) (tok lexbuf) 
      | Token.Open ("ol",_)  -> list "ol" [] (fun l -> next (OrderedList l)) (tok lexbuf) 
      | Token.Open ("h1",_)  -> inline (Some "h1") [] (fun l -> next (Heading (1, l))) (tok lexbuf) 
      | Token.Open ("h2",_)  -> inline (Some "h2") [] (fun l -> next (Heading (2, l))) (tok lexbuf) 
      | Token.Open ("h3",_)  -> inline (Some "h3") [] (fun l -> next (Heading (3, l))) (tok lexbuf) 
      | Token.Open ("h4",_)  -> inline (Some "h4") [] (fun l -> next (Heading (4, l))) (tok lexbuf) 
      | Token.Open ("h5",_)  -> inline (Some "h5") [] (fun l -> next (Heading (5, l))) (tok lexbuf) 
      | Token.Open ("h6",_)  -> inline (Some "h6") [] (fun l -> next (Heading (6, l))) (tok lexbuf) 
      | Token.Open ("blockquote",_) -> block (Some "blockquote") [] (fun l -> next (Blockquote l)) (tok lexbuf) 

      | Token.Open (tag,_)   -> error "Unexpected opening tag <%s>" tag

  and list close acc (return : block list list -> Token.t -> 'a) = 
    let next r tok = list close (r :: acc) return tok in 
    function 

      | Token.Eof -> error "Unexpected end of string in <%s>" close
      | Token.Close tag -> if tag = close then return (List.rev acc) (tok lexbuf) 
                           else error "Unexpected closing tag </%s> for <%s>" tag close

      | Token.Text _ -> error "Unexpected text in <%s>" close

      | Token.Open ("li",_) -> block (Some "li") [] next (tok lexbuf)

      | Token.Open (tag,_) -> error "Unexpected <%s> in <%s>" tag close

  in
			   
  block None [] (fun l _ -> l) (tok lexbuf) 
