(* © 2014 RunOrg *)

(** The identifier of a group. The identifier is implicitly part of a database, 
    so two databases may contain two groups with the same identifier. *)

include Id.PHANTOM

val is_admin : 'a id -> bool

val admin : t
