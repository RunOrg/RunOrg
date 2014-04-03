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
  | `List of < groups : Group.I.t Set.t ; contacts : CId.t Set.t >
  ]

(** The maximum number of groups or contacts in a list. *)
val max_item_count : int

(** An empty audience, representing no one. *)
val empty : t

(** Returns true if a specified contact is member of the provided audience. 
    This is used for membership purposes, as opposed to authorization. *)
val is_member : CId.t -> t -> (#O.ctx, bool) Run.t

(** Returns true if a specified contact is a member of any of the provided
    audiences, or an administrator. This is used for authorization purposes. *)
val is_allowed : CId.t -> t list -> (#O.ctx, bool) Run.t 

