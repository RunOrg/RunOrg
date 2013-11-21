(* © 2013 RunOrg *)

(** Validates an assertion, returning the corresponding e-mail. *)
val validate : audience:string -> string -> ('ctx, string option) Run.t

