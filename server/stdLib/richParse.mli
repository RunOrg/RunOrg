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

(** When a parser error occurs. Includes the number of the character 
    that caused the error. *)
exception ParseError of int * string

(** Attempt to parse a string, using an UTF-8 tokenization function 
    (such as [RichLex.token]). Being an UTF-8 tokenization function 
    means accepting the standard [lexbuf] object, along with an integer
    reference that counts the number of UTF-8 code points encountered
    so far. 
    @raise ParseError if a parsing error occurred. *)
val parse : (int ref -> Lexing.lexbuf -> Token.t) -> string -> RichText.t
