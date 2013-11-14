module Pack : sig
  type t 
  type 'a packer = 'a -> t -> unit
  val string : string packer
  val int : int packer
  val float : float packer
  val bool : bool packer
  val none : t -> unit
  val list : 'a packer -> 'a list packer
  val map : 'k packer -> 'v packer -> ('k * 'v) list packer
  val option : 'a packer -> 'a option packer
end

module Unpack : sig
  type t
  type 'a unpacker = t -> 'a
  val string : t -> string
  val int : t -> int
  val bool : t -> bool
  val float : t -> float
  val option : (t -> 'a) -> t -> 'a option 
  val list : (t -> 'a) -> t -> 'a list
  val map : (t -> 'k) -> (t -> 'v) -> t -> ('k * 'v) list
  val recursive : 
    ?string:(string -> 'a) ->
    ?int:(int -> 'a) ->
    ?float:(float -> 'a) ->
    ?bool:(bool -> 'a) ->
    ?null:'a ->
    ?list:('a list -> 'a) ->
    ?map:(('a * 'a) list -> 'a) ->
    t -> 'a
end

(* Raw functions, used internally by the syntax extension. Don't use them. *)
module Raw : sig
  val start_array : int -> Pack.t -> unit
  val expect_none : Unpack.t -> unit
  val expect_array : int -> Unpack.t -> unit
  val open_array : Unpack.t -> int
  val size_was : int -> int -> unit
  val bad_variant : int -> 'a
end

exception Error of string

type 'a packer = 'a Pack.packer
type 'a unpacker = 'a Unpack.unpacker

val to_string : 'a packer -> 'a -> string
val of_string : 'a unpacker -> string -> 'a 
