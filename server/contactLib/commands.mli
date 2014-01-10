(* © 2014 RunOrg *)

(** Create a new contact with the specified e-mail, and return its identifier. 
    If the e-mail already belongs to a contact, the identifier of that contact
    is returned instead. *)
val create : string -> (# O.ctx, I.t * Cqrs.Clock.t) Run.t
