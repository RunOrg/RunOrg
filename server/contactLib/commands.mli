(* © 2014 RunOrg *)

(** Create a new contact with the specified e-mail, and return its identifier. 
    If the e-mail already belongs to a contact, the identifier of that contact
    is returned instead. *)
val create : 
  ?fullname:string -> 
  ?firstname:string -> 
  ?lastname:string -> 
  ?gender:[`F|`M] -> 
  string -> (# O.ctx, I.t * Cqrs.Clock.t) Run.t

