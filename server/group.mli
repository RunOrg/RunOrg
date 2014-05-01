(* © 2014 RunOrg *)

open Std

(** Groups are sets of people. *)

(** Access levels on a group. *)
module Access : Access.T with type t = 
  [ `Admin    (** Can do everything *)
  | `Moderate (** Can add/remove people *)
  | `List     (** Can view list of people *)
  | `View     (** Knows that the group exists *) ]

(** Create a new group. 
    @param label A name that can be displayed to users. Groups without a label do not appear in 
                 most group lists. 
    @param id A custom identifier. Must be alphanumeric and 10 or fewer characters long. If a 
              group with that identifier already exists, nothing happens. *)
val create : 
   PId.t option ->
  ?label:String.Label.t -> 
  ?id:CustomId.t ->   
   Access.Audience.t -> (#O.ctx, [ `OK of GId.t * Cqrs.Clock.t
				 | `NeedAccess of Id.t
				 | `AlreadyExists of CustomId.t ]) Run.t

(** Add people to groups. Nothing happens if a contact or a group does not exist, 
    or if the contact is already in the group. *)
val add : PId.t option -> PId.t list -> GId.t list -> (#O.ctx, [ `OK of Cqrs.Clock.t
							       | `NeedModerator of GId.t 
							       | `MissingPerson of PId.t
							       | `NotFound of GId.t ]) Run.t

(** As [add], but skips access level checks. *)
val add_forced : PId.t list -> GId.t list -> (#O.ctx, Cqrs.Clock.t) Run.t

(** Remove contacts from groups. Nothing happens if a contact or a group does not 
    exist, or if the contact is not in the group. *)
val remove : PId.t option -> PId.t list -> GId.t list -> (#O.ctx, [ `OK of Cqrs.Clock.t
								  | `NeedModerator of GId.t 
								  | `NotFound of GId.t ]) Run.t

(** Delete a group. If the group does not exist (or is delete-protected), nothing 
    happens. *)
val delete : PId.t option -> GId.t -> (# O.ctx, [ `OK of Cqrs.Clock.t
						| `NeedAdmin of GId.t 
						| `NotFound of GId.t ]) Run.t

(** List the members of a group. *)
val list : PId.t option -> ?limit:int -> ?offset:int -> GId.t 
  -> (#O.ctx, [ `OK of PId.t list * int
	      | `NotFound of GId.t 
	      | `NeedList of GId.t ]) Run.t

(** List the members of a group, reserved for internal usage. Please ensure that you
    have the correct access level before using this function. *)
val list_force : ?limit:int -> ?offset:int -> GId.t -> (#O.ctx, PId.t list) Run.t

(** Short information about a group. *)
type short = <
  id     : GId.t ; 
  label  : String.Label.t option ;
  access : Access.Set.t ;
  count  : int option ;
>

(** All meta-information about a group. *)
type info = <
  id       : GId.t ; 
  label    : String.Label.t option ;
  access   : Access.Set.t ;
  count    : int option ;
  audience : Access.Audience.t option ; 
>

(** Get short information about a group. *)
val get : PId.t option -> GId.t -> (#O.ctx, info option) Run.t 

(** Get short information about several groups. *)
val get_many : PId.t option -> GId.t list -> (#O.ctx, info list) Run.t 

(** Get all the groups in the database. *)
val all : PId.t option -> limit:int -> offset:int -> (#O.ctx, short list) Run.t

(** List all the groups of a person. *)
val of_person : PId.t -> (#O.ctx, GId.t Set.t) Run.t 
