(* © 2014 RunOrg *)

open Std

(** Fields are usually found in forms. They represent an atomic level of data. *)

(** A field identifier. Supports custom identifiers. *)
module I : sig
  include Id.PHANTOM
  val of_custom : CustomId.t -> t
end

(** The maximum number of choices in a field. *)
val max_choices : int

(** A possible individual choice in a single/multiple choice field. 
    A string is automatically treated as a label. Any other kind of value
    is processed as custom JSON. *)
module Choice : Fmt.FMT with type t = 
  [ `Label of String.Label.t 
  | `Custom of Json.t ]

(** The different types of fields available. *)
module Kind : Fmt.FMT with type t = 
  [ `Text
  | `RichText
  | `DateTime
  | `SingleChoice   of Choice.t list
  | `MultipleChoice of Choice.t list 
  | `Json 
  | `Contact
  ]

(** Meta-information about a field. *)
include Fmt.FMT with type t = <
  id       : I.t ;
  kind     : Kind.t ;
  label    : String.Label.t ;
  custom   : Json.t ; 
  required : bool ;
> 

(** Handy constructor. *)
val make : required:bool -> custom:Json.t -> label:String.Label.t -> kind:Kind.t -> id:I.t -> t

(** Returns true if the data is valid for the provided kind. 
    [Null] is always valid for any data (absence of data is handled by the [required] 
    property, rather than by individual kinds). *)
val check : Kind.t -> Json.t -> (#O.ctx, bool) Run.t
