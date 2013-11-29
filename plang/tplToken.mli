(* © 2013 RunOrg *)

(** Creates a new lexer function (called repeatedly on a lexing
    buffer and returns a new token each time) *)
val make : unit -> Lexing.lexbuf -> TplParse.token
