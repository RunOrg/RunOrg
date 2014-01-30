(* © 2013 RunOrg *)

(** Attempt to log in with persona. Returns a token and the e-mail used for login,
    or [None] if authentication failed (assertion is incorrect, or user is not a 
    server administrator) *)
val auth_persona : string -> (# Cqrs.ctx, ([`ServerAdmin] Token.I.id * string) option) Run.t

(** Attempt to log in using test mode. Returns a token and the e-mail of one of the
    server administrators, or [None] if test mode is disabled. *)
val auth_test : unit -> (# Cqrs.ctx, ([`ServerAdmin] Token.I.id * string) option) Run.t

(** The list of all adminstrators. [fromConfig] determines whether an administrator 
    is present in the list because it is in the configuration file. *)
val all : [`ServerAdmin] Token.I.id -> (# Cqrs.ctx, < email : string ; fromConfig : bool > list) Run.t
