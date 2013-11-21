(* © 2013 RunOrg *)

(** Attempt to log in with persona. Returns a token and the e-mail used for login,
    or [None] if authentication failed (assertion is incorrect, or user is not a 
    server administrator) *)
val auth_persona : string -> (# Cqrs.ctx, ([`ServerAdmin] Token.I.id * string) option) Run.t

 
