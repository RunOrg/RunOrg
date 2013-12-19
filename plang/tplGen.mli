(* © 2013 RunOrg *)

(** Compiling templates to JavaScript code. *)

(** Compiles all the provided templates to JavaScript. Each template is provided
    along with its path. Intended to be inserted as variable {{ TEMPLATES }} into
    the builtin files. *)
val compile : (string list * TplAst.file) list -> string

