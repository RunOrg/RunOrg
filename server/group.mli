(* © 2014 RunOrg *)

(** Groups are sets of contacts. *)

module I : sig
  include Id.PHANTOM
end

(** Create a new group. 
    @param label A name that can be displayed to users. Groups without a label do not appear in 
                 most group lists. 
    @param id A custom identifier. Must be alphanumeric and 10 or fewer characters long. If a 
              group with that identifier already exists, nothing happens. *)
val create : 
  ?label:string -> 
  ?id:CustomId.t -> 
  unit -> (#O.ctx, I.t * Cqrs.Clock.t) Run.t

(** Add contacts to groups. Nothing happens if a contact or a group does not exist, 
    or if the contact is already in the group. *)
val add : CId.t list -> I.t list -> (#O.ctx, Cqrs.Clock.t) Run.t

(** Remove contacts from groups. Nothing happens if a contact or a group does not 
    exist, or if the contact is not in the group. *)
val remove : CId.t list -> I.t list -> (#O.ctx, Cqrs.Clock.t) Run.t

(** Delete a group. If the group does not exist, nothing happens. *)
val delete : I.t -> (# O.ctx, Cqrs.Clock.t) Run.t
