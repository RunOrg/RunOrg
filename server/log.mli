(* © 2013 RunOrg *)

(** The log module writes logs to standard output (when in [RESET] mode) or to the
    disk in an appropriately named and timed file: [2013-11-02/web.error.log] *)

(** Log a trace-level piece of information, output to [{date}/{role}.log]. *)
val trace : ('a,unit,string,unit) format4 -> 'a

(** Log an error-level piece of information, output to [{date}/{role}.error.log]. *)
val error : ('a,unit,string,unit) format4 -> 'a

(** Prints the last exception raised in the current thread. *)
val exn : exn -> string -> unit
