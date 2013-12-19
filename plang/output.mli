(* © 2013 RunOrg *)

(** Outputs compiled files to disk. *)

(** Writes the result of a build to the specified directory, as 
    files [all.js] and [all.css] *)
val write : string -> Build.t -> unit
