(* © 2014 RunOrg *)

(** A human-readable alternative to standard unique identifiers. 
    Custom identifiers must follow the regexp [[a-zA-Z0-9]{1,10}]
    (that is, contain only alphanumeric characters, and be between one
    and ten characters long). *)

(** The type of a custom identifier. *)
type t

(** Convert a custom identifier to a normal identifier. *)
val to_id : t -> Id.t

(** The string representation of a custom identifier. *)
val to_string : t -> string

(** Attempt to turn a string into a custom identifier. Returns [None] if
    the string is not valid. *)
val validate : string -> t option 
