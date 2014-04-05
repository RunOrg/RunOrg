(* © 2014 RunOrg *)

open Std

(** An audience is a set of contacts, represented as a union of groups and a (short)
    list of individual contacts. It can also be represented as "anyone". 

    The JSON representation is either the string ["anyone"], or an object with 
    fields [{"groups":[...],"contacts":[...]}] where both fields are optional
    and assumed to be empty if missing. 
*)

include Fmt.FMT with type t = 
  [ `Anyone
  | `List of < groups : GId.t Set.t ; contacts : CId.t Set.t >
  ]

(** The maximum number of groups or contacts in a list. *)
val max_item_count : int

(** An empty audience, representing no one. *)
val empty : t

(** Returns true if a specified contact is member of the provided audience. 
    This is used for membership purposes, as opposed to authorization. 

    Note that storing [is_member id] and using it multiple times will avoid
    extraneous queries to the database. 
*)
val is_member : CId.t option -> t -> (#O.ctx, bool) Run.t

(** Merges two audiences into one. *)
val union : t -> t -> t

(** An audience representing only the [admin] group. *)
val admin : t

(** Used by the group module to register a specific "list groups of contact"
    function. *)
val register_groups_of_contact : (CId.t -> ( O.ctx, GId.t Set.t ) Run.t) -> unit

(** Returns the list of all groups that a contact belongs to. *)
val of_contact : CId.t -> ( O.ctx, GId.t Set.t ) Run.t
