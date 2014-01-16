(* © 2014 RunOrg *)

(** Contacts represent people who can connect to the system and receive e-mails. *)

(** The type of a contact identifier. *)
module I : sig
  include Id.PHANTOM
end

(** Create a new contact with the specified e-mail, and return its identifier. 
    If the e-mail already belongs to a contact, the identifier of that contact
    is returned instead. *)
val create : 
  ?fullname:string -> 
  ?firstname:string -> 
  ?lastname:string -> 
  ?gender:[`F|`M] -> 
  string -> (# O.ctx, I.t * Cqrs.Clock.t) Run.t
  
