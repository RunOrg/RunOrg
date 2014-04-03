(* © 2014 RunOrg *)

open Std

(** Forms collect information about things (e.g. contacts) in a dictionary-of-fields format. 
    Each form has a specific list of fields which are then filled. Each 'filled form' is a
    dataset bound to both a form and one of the objects the form is related to. *)

(** The identifier of an individual form. Supports custom identifiers. *)
module I : sig
  include Id.PHANTOM
  val of_custom : CustomId.t -> t
end

(** The possible owners of a form - each filled form will be tied to one entity of
    this type. *)
module Owner : Fmt.FMT with type t = 
  [ `Contact ]

(** The identifier of an individual owner. *)
module FilledI : Fmt.FMT with type t = 
  [ `Contact of CId.t ]

(** The audience of a form. *)
module Audience : Fmt.FMT with type t = <
  admin : Audience.t ;
  fill  : Audience.t ;
>

(** Current information about a form. *)
type info = <
  id     : I.t ;
  owner  : Owner.t ;
  label  : String.Label.t option ; 
  fields : Field.t list ;
  custom : Json.t ;
  empty  : bool ; 
> 

(** Create a new form. 
    @param label A name that can be displayed to users. Forms without a label do not 
                 appear in most group lists.
    @param id A custom identifier. Must be alphanumeric and 10 or fewer characters long.
              If a form with that identifier already exists, returns [None]. *)
val create :
  ?label:String.Label.t ->
  ?id:CustomId.t -> 
  Owner.t ->
  Json.t -> 
  Field.t list -> (#O.ctx, I.t option * Cqrs.Clock.t) Run.t

(** Get short information about a form. *)
val get : I.t -> (#O.ctx, info option) Run.t

(** The type of a fill error. *)
module Error : Fmt.FMT with type t = 
  [ `NoSuchForm of I.t
  | `NoSuchField of I.t * Field.I.t
  | `MissingRequiredField of I.t * Field.I.t
  | `InvalidFieldFormat of I.t * Field.I.t * Field.Kind.t
  | `NoSuchOwner of I.t * FilledI.t 
  ]

(** Fill in a form based on its identifier. Either fails with an explicit error, 
    or returns the clock when the fill-in is done. *)
val fill : 
  I.t ->
  FilledI.t -> 
  (Field.I.t, Json.t) Map.t -> (#O.ctx, (Cqrs.Clock.t, Error.t) result) Run.t

(** Get the filled data for a form. *)
val get_filled : 
  I.t ->
  FilledI.t ->
  (#O.ctx, (Field.I.t, Json.t) Map.t option) Run.t

