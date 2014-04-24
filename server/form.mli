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
  [ `Person ]

(** The identifier of an individual owner. *)
module FilledI : Fmt.FMT with type t = 
  [ `Person of PId.t ]

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
  PId.t option -> 
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
  PId.t option -> 
  I.t -> (# O.ctx, [ `OK of Cqrs.Clock.t
		   | `NoSuchForm of I.t 
		   | `NeedAdmin of I.t
		   | `FormFilled of I.t ] ) Run.t

(** Get short information about a form. *)
val get : I.t -> (#O.ctx, info option) Run.t

(** List all forms that can be seen by the provided person. *)
val list : PId.t option -> limit:int -> offset:int -> (#O.ctx, info list) Run.t

(** Fill in a form based on its identifier. Either fails with an explicit error, 
    or returns the clock when the fill-in is done. *)
val fill : 
  PId.t option ->
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

(** A filled instance of a form. *)
type filled = <
  updated : Time.t ;
  owner   : FilledI.t ;
  data    : (Field.I.t, Json.t) Map.t ;
>

(** Get the filled data for a form. *)
val get_filled :
  PId.t option -> 
  I.t ->
  FilledI.t ->
  (#O.ctx, [ `NoSuchForm of I.t
	   | `NotFilled of I.t * FilledI.t 
	   | `NeedAdmin of I.t * FilledI.t
	   | `OK of (Field.I.t, Json.t) Map.t 
	   ]) Run.t

(** List filled instances for a form. *)
val list_filled :
  PId.t option ->
  ?limit:int ->
  ?offset:int ->
  I.t -> 
  (#O.ctx, [ `NoSuchForm of I.t
	   | `NeedAdmin of I.t
	   | `OK of < count : int ; list : filled list > 
	   ]) Run.t

(** Form statistics *)
module Stats : sig 

  (** Statistics about a single form field. JSON serialization ignores the
      variand and returns an object with properties appropriate to the field
      kind. *)
  module FieldStat : Fmt.FMT with type t = 
    [ `Text of <
        missing : int ;
        filled  : int ;
      >
    | `Time of <
        missing : int ;
        filled  : int ;
	first   : Time.t option ;
	last    : Time.t option ;
      >
    | `Json of <
        missing   : int ;
        filled    : int ;
      >
    | `Single of <
        missing : int ;
        filled  : int ;
	items   : int array ;
      >
    | `Multi of <
        missing : int ;
        filled  : int ;
	items   : int array ;
      >
    | `Person of <
        missing : int ;
        filled : int ;
	contacts : int ;
	top10 : (PId.t * int) list ;
      >
    ]

  (** Maps statistics to fields, represented as a JSON dictionary. *)
  module Summary : Fmt.FMT with type t = 
    ( Field.I.t, FieldStat.t ) Map.t

end

(** Compute and return statistics for a form. *)
val stats : 
  PId.t option ->
  I.t ->
  (#O.ctx, [ `NoSuchForm of I.t
	   | `NeedAdmin of I.t
	   | `OK of < fields : Stats.Summary.t ; count : int ; updated : Time.t option >
	   ]) Run.t
