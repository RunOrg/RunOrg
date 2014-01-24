(* © 2013 RunOrg *)

let protect ?save f v = 
  try Some (f v)
  with Json.Error (_,error) ->
    match save with None -> None | Some g -> 
      try Some (f (g v)) with _ -> None

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

module Extend = functor (Type : sig
  type t 
  val t_of_json : Json.t -> t
  val json_of_t : t -> Json.t
  val pack : t Pack.packer
  val unpack : t Pack.unpacker
end) -> struct

  let of_json = Type.t_of_json
  let to_json = Type.json_of_t
  let of_json_safe = protect of_json

  let of_json_string_safe str = 
    try of_json_safe (Json.unserialize str)
    with _ -> None
  
  let to_json_string t = 
    Json.serialize (to_json t)
            
  let pack   = Type.pack
  let unpack = Type.unpack

end

module ReadExtend = functor (Type : sig
  type t 
  val t_of_json : Json.t -> t
  val unpack : t Pack.unpacker
end) -> struct

  let of_json = Type.t_of_json

  let of_json_safe = protect of_json

  let of_json_string_safe str = 
    try of_json_safe (Json.unserialize str)
    with _ -> None
  
  let unpack = Type.unpack

end

module Make = functor (Type : sig 
  type t 
  val t_of_json : Json.t -> t
  val json_of_t : t -> Json.t
  val pack : t Pack.packer
  val unpack : t Pack.unpacker
end) -> struct
  type t      = Type.t
  include Extend(Type)
end

module PackAsJson =  functor(Type : sig
  type t
  val t_of_json : Json.t -> t
  val json_of_t : t -> Json.t
end) -> struct
  open Type
  let pack t p = Json.pack (json_of_t t) p
  let unpack u = t_of_json (Json.unpack u)
end
