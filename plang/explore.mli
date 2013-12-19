(* © 2013 RunOrg *)

(** Explore the input directory, looking for files to be compiled. *)

(** The type of an exploration file. This is the relative path to the
    input directory, split up into segments. *)
type path = string list 

(** The type of an exploration result. Lists all the files found in 
    each category: i18n (per language), templates and javascript 
    source. Paths are relative to the root path. *)
type result = {
  root : string ; 
  i18n : (string * path list) list ;
  templates : path list ;
  javascript : path list ; 
}

(** A printable representation of an exploration result. *)
val to_string : result -> string

(** Explore a directory. [explore path] looks for all files within 
    the path that match one of the categories, recursively. *)
val explore : string -> result 

