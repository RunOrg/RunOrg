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
  val compute : CId.t option -> Audience.t -> (#O.ctx, Set.t) Run.t

  (** A log-friendly representation of a set. *)
  val set_to_string : Set.t -> string
				   
end

(** Representing an audience set based on a list of access levels. *)
module Make : functor (Access:ACCESS_LEVEL) -> T with type t = Access.t
