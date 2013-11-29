(* © 2013 RunOrg *)

(** An error raised when parsing. *)
exception Error

(** The type of tokens to be provided to the parser. *)
type token = 
  | Self
  | Or
  | OpenParen
  | OpenBracket
  | Not
  | Name of string
  | Literal of string
  | Int of int
  | Html of string
  | Eof
  | EndSub
  | EndI18n
  | EndEcho
  | EndCall
  | Dot
  | Comparison of TplAst.comparison
  | CloseParen
  | CloseBracket
  | Block of string
  | BeginSub
  | BeginI18n
  | BeginEcho
  | BeginCall
  | BeginBlock
  | And

(** Parse a template file. *)
val file: (Lexing.lexbuf -> token) -> Lexing.lexbuf -> TplAst.file
