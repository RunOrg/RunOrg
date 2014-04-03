(* © 2013 RunOrg *)

module type FMT = sig
  type t 
  val of_json : Json.t -> t
  val to_json : t -> Json.t
  val of_json_safe : Json.t -> t option
  val of_json_string_safe : string -> t option
  val to_json_string : t -> string
  val pack : t Pack.packer
  val unpack : t Pack.unpacker
end

module type READ_FMT = sig
  type t  
  val of_json : Json.t -> t
  val of_json_safe : Json.t -> t option
  val of_json_string_safe : string -> t option 
  val unpack : t Pack.unpacker
end

module Make : functor (Type : sig
  type t
  val t_of_json : Json.t -> t
  val json_of_t : t -> Json.t
  val pack : t Pack.packer
  val unpack : t Pack.unpacker
end ) -> FMT with type t = Type.t

module PackAsJson : functor(Type : sig
  type t
  val t_of_json : Json.t -> t
  val json_of_t : t -> Json.t
end) -> sig
  open Type
  val pack : t Pack.packer
  val unpack : t Pack.unpacker
end

module Extend : functor (Type : sig 
  type t 
  val t_of_json : Json.t -> t
  val json_of_t : t -> Json.t
  val pack : t Pack.packer
  val unpack : t Pack.unpacker
end ) -> sig
  open Type
  val of_json : Json.t -> t
  val to_json : t -> Json.t
  val of_json_safe : Json.t -> t option
  val of_json_string_safe : string -> t option
  val to_json_string : t -> string
  val pack : t Pack.packer
  val unpack : t Pack.unpacker
end

module ReadExtend : functor (Type : sig
  type t
  val t_of_json : Json.t -> t
  val unpack : t Pack.unpacker
end) -> sig
  open Type
  val of_json : Json.t -> t
  val of_json_safe : Json.t -> t option
  val of_json_string_safe : string -> t option 
  val unpack : t Pack.unpacker
end

module Map : functor (Type : sig
  module Inner : FMT
  type t 
  val from_inner : Inner.t -> t
  val to_inner : t -> Inner.t
end) -> FMT with type t = Type.t
