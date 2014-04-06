(* © 2014 RunOrg *)

(** Managing access levels and their relationship to audiences. *)

open Std

(** Access levels are polymorphic variant types with no parameters. They can be serialized to 
    and from strings, which makes them available as keys in dictionaries. *)
module type ACCESS_LEVEL = sig

  include Fmt.FMT

  (** A list of all available access levels, each level is associated with the
      ones it implicitely grants it, such as [[`Admin, [`Fill] ; `Fill, []]]. *)
  val all : (t * (t list)) list 

end

module type T = sig

  include Fmt.FMT 

  (** A set of audiences, one for each access level. Serializable as a 
      dictionary with the access levels as the string keys. *)
  module Audience : Fmt.FMT with type t = ( t, Audience.t ) Map.t

  (** A set of access levels. Serializable as a list of strings.  *)
  module Set : Fmt.FMT with type t = t Set.t

  (** Based on an audience set, find the access levels granted to a specific
      user. *)
  val compute : CId.t option -> Audience.t -> (# Cqrs.ctx, Set.t) Run.t

  (** A log-friendly representation of a set. *)
  val set_to_string : Set.t -> string

  (** An accessor view, used for finding lists of values based on their 
      access level. Answers the question "what items can this 'as' identity 
      manipulate at that access level?", e.g. "what can this user 'view'?" 
  *)
  type 'id accessor

  (** Accessor map module. *)
  module Map : sig

    (** Create an accessor view using this access model. If [only] is provided,
	then only that list of access levels will be available for indexing. *)
    val make : Cqrs.Projection.t -> string -> int -> ?only:t list ->
      (module Fmt.FMT with type t = 'id) ->
      Cqrs.Projection.view * 'id accessor

    (** Update the audience bound to an identifier, making it available based on that
	audience. If the identifier does not exist, it is created. *)
    val update : 'id accessor -> 'id -> Audience.t -> # Cqrs.ctx Run.effect

    (** Removes an identifier from the accessor view. *)
    val remove : 'id accessor -> 'id -> # Cqrs.ctx Run.effect

    (** Lists all the identifiers that are available at the specified access 
	level for the provided contact. *)
    val list : 
      ?limit:int -> 
      ?offset:int -> 
      'id accessor -> 
      CId.t option -> 
      t -> 
      (# Cqrs.ctx, 'id list) Run.t

  end
      				   
end

(** Representing an audience set based on a list of access levels. *)
module Make : functor (Access:ACCESS_LEVEL) -> T with type t = Access.t
