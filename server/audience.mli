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
  | `List of < groups : GId.t Set.t ; people : PId.t Set.t >
  ]

(** The maximum number of groups or contacts in a list. *)
val max_item_count : int

(** An empty audience, representing no one. *)
val empty : t

(** Returns true if a specified person is member of the provided audience. 
    This is used for membership purposes, as opposed to authorization. 

    Note that storing [is_member id] and using it multiple times will avoid
    extraneous queries to the database. 
*)
val is_member : PId.t option -> t -> (# Cqrs.ctx, bool) Run.t

(** Merges two audiences into one. *)
val union : t -> t -> t

(** An audience representing only the [admin] group. *)
val admin : t

(** Used by the group module to register a specific "list groups of person"
    function. *)
val register_groups_of_person : (PId.t -> ( Cqrs.ctx, GId.t Set.t ) Run.t) -> unit

(** Returns the list of all groups that a person belongs to. *)
val of_person : PId.t -> ( Cqrs.ctx, GId.t Set.t ) Run.t
