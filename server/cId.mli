(* © 2014 RunOrg *)

(** The identifier of a contact. The identifier is implicitly part of a database, 
    so two databases may contain two contacts with the same identifier. *)

include Id.PHANTOM

module Assert : sig
    
  (** Marks this contact as "currently authenticated" *)
  val auth : 'a id -> [`Auth] id

end

(** Returns true if the two identifiers refer to the same contact. 
    Better than '=' in that it ignores the phantom type tag. *)
val eq : 'a id -> 'b id -> bool 
