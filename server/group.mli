(* © 2014 RunOrg *)

open Std

(** Groups are sets of contacts. *)

(** Create a new group. 
    @param label A name that can be displayed to users. Groups without a label do not appear in 
                 most group lists. 
    @param id A custom identifier. Must be alphanumeric and 10 or fewer characters long. If a 
              group with that identifier already exists, nothing happens. *)
val create : 
  ?label:String.Label.t -> 
  ?id:CustomId.t -> 
  CId.t option -> (#O.ctx, [ `OK of GId.t * Cqrs.Clock.t
			   | `NeedAccess of Id.t
			   | `AlreadyExists of CustomId.t ]) Run.t

(** Add contacts to groups. Nothing happens if a contact or a group does not exist, 
    or if the contact is already in the group. *)
val add : CId.t list -> GId.t list -> (#O.ctx, Cqrs.Clock.t) Run.t

(** Remove contacts from groups. Nothing happens if a contact or a group does not 
    exist, or if the contact is not in the group. *)
val remove : CId.t list -> GId.t list -> (#O.ctx, Cqrs.Clock.t) Run.t

(** Delete a group. If the group does not exist (or is delete-protected), nothing 
    happens. *)
val delete : GId.t -> (# O.ctx, Cqrs.Clock.t) Run.t

(** List the members of a group. *)
val list : ?limit:int -> ?offset:int -> GId.t -> (#O.ctx, CId.t list * int) Run.t

(** Short information about a group. *)
type info = <
  id    : GId.t ; 
  label : String.Label.t option ;
  count : int ;
>

(** Get short information about a group. *)
val get : GId.t -> (#O.ctx, info option) Run.t 

(** Get all the groups in the database. *)
val all : limit:int -> offset:int -> (#O.ctx, info list * int) Run.t

(** List all the groups of a contact. *)
val of_contact : CId.t -> (#O.ctx, GId.t Set.t) Run.t 
