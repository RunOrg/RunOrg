(* © 2013 RunOrg *)

(** Parses command-line arguments and exposes them in a clean 
    manner. 

    Typical syntax: [plang ./source ./output] *)

(** The path to the source directory. *)
val source_directory : string

(** The path to the output directory. *)
val output_directory : string
