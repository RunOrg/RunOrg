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
module Access : Access.T with type t = 
  [ `Admin | `Fill ]

(** Current information about a form. *)
type info = <
  id       : I.t ;
  owner    : Owner.t ;
  label    : String.Label.t option ; 
  fields   : Field.t list ;
  custom   : Json.t ;
  empty    : bool ; 
  audience : Access.Audience.t ;
> 

(** Create a new form as the specified user. 
    @param label A name that can be displayed to users. Forms without a label do not 
                 appear in most group lists.
    @param id A custom identifier. Must be alphanumeric and 10 or fewer characters long.
              If a form with that identifier already exists, returns [None]. 
    @param owner The owner of the form to be created. 
    @param audience The audience set, specifying all access levels. 
    @param custom An arbitrary JSON value, kept as-is. *)
val create :
  CId.t option -> 
  ?label:String.Label.t ->
  ?id:CustomId.t -> 
  owner:Owner.t ->
  audience:Access.Audience.t -> 
  custom:Json.t -> 
  Field.t list -> (#O.ctx, [ `OK of I.t * Cqrs.Clock.t
			   | `NeedAccess of Id.t
			   | `AlreadyExists of CustomId.t ] ) Run.t

(** Update an existing form. If the form was filled and the [fields] are updated, 
    will fail atomically (either immediately, or a short while later). *)
val update : 
  ?label:String.Label.t option ->
  ?owner:Owner.t ->
  ?audience:Access.Audience.t ->
  ?custom:Json.t ->
  ?fields:Field.t list ->
  CId.t option -> 
  I.t -> (# O.ctx, [ `OK of Cqrs.Clock.t
		   | `NoSuchForm of I.t 
		   | `NeedAdmin of I.t
		   | `FormFilled of I.t ] ) Run.t

(** Get short information about a form. *)
val get : I.t -> (#O.ctx, info option) Run.t

(** List all forms that can be seen by the provided contact. *)
val list : CId.t option -> limit:int -> offset:int -> (#O.ctx, info list) Run.t

(** Fill in a form based on its identifier. Either fails with an explicit error, 
    or returns the clock when the fill-in is done. *)
val fill : 
  CId.t option ->
  I.t ->
  FilledI.t -> 
  (Field.I.t, Json.t) Map.t -> (#O.ctx, [ `OK of Cqrs.Clock.t
					| `NoSuchForm of I.t
					| `NoSuchField of I.t * Field.I.t
					| `MissingRequiredField of I.t * Field.I.t
					| `InvalidFieldFormat of I.t * Field.I.t * Field.Kind.t
					| `NoSuchOwner of I.t * FilledI.t 
					| `NeedAdmin of I.t * FilledI.t					
					]) Run.t

(** Get the filled data for a form. *)
val get_filled :
  CId.t option -> 
  I.t ->
  FilledI.t ->
  (#O.ctx, [ `NoSuchForm of I.t
	   | `NotFilled of I.t * FilledI.t 
	   | `NeedAdmin of I.t * FilledI.t
	   | `OK of (Field.I.t, Json.t) Map.t 
	   ]) Run.t
