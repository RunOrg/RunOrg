(* © 2014 RunOrg *)

(** A recursive descent parser for rich text markup. *)

module Token : sig

  (** The type of tokens expected by the parser. *)
  type t = 
    | Text of string
    | Open of string * (string * string) list 
    | Close of string
    | Eof 

end

(** An inline element: anything which is displayed within a 
    paragraph of text. *)
type inline = 
| Text of string
| Strong of inline list
| Emphasis of inline list
| Anchor of string * inline list

(** A block element: anything which takes up all space horizontally. *)
type block = 
| Paragraph of inline list
| UnorderedList of block list list
| OrderedList of block list list
| Blockquote of block list
| Heading of int * inline list

(** A rich text element is a list of blocks. *)
type t = block list 

(** When a parser error occurs. Includes the number of the character 
    that caused the error. *)
exception ParseError of int * string

(** Attempt to parse a string, using an UTF-8 tokenization function 
    (such as [RichLex.token]). Being an UTF-8 tokenization function 
    means accepting the standard [lexbuf] object, along with an integer
    reference that counts the number of UTF-8 code points encountered
    so far. 
    @raise ParseError if a parsing error occurred. *)
val parse : (int ref -> Lexing.lexbuf -> Token.t) -> string -> t
