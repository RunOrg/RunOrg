(* © 2014 RunOrg *)

(** UnTuring is the DSL used by RunOrg to describe data
    processing. Its design goals are easy generation (it will be the
    target of compilers), easy static analysis (to prove bounds on
    execution time and memory usage) and helpful primitives for processing
    data. *)

(** A compiled script. *)
type script 

(** Compile a script. If an error occurs, returns [None]. *)
val compile : string -> script option 

(** Run the script in simple data transformation mode. *)
val run : 
  inline:Json.t ->
  context:Json.t -> 
  script -> Json.t 
