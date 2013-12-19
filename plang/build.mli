(* © 2013 RunOrg *)

(** Builds the output CSS and JavaScript from an exploration. *)

(** The type of a result: the CSS and JS source code. *)
type t = {
  css  : string ;
  js   : string ; 
  i18n : (string * string) list ;
}

(** Build the output. Optionally provide a 'builtins' string, otherwise will use 
    [./plang/builtins] as the source for built-in javascript and CSS. *)
val build : ?builtins:string -> Explore.result -> t
