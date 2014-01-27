(* © 2014 RunOrg *)

(** Testing system. The implementation for this interface is auto-generated
    from the 'test' root directory. *)

(** The list of all available test files, as paths relative to the test directory, 
    along with JSON-encoded meta-data about those files. *)
val all : (string * Json.t) list
