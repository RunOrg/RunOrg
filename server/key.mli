(* © 2014 RunOrg *)

(** Cryptographic signature keys. Global (per-database). *)

(** The identifier of a key. *)
module I : sig
  include Id.PHANTOM
end

(** All supported hash functions. *)
module Hash : Fmt.FMT with type t = [ `SHA1 ]

(** Create a new key in the current database, using the provided hash and bytes. *)
val create : IpAddress.t -> Hash.t -> string -> ( #O.ctx, I.t * Cqrs.Clock.t ) Run.t

(** HMAC a sequence of bytes with the specified key. Returns [None] if the key does 
    not exist. *)
val hmac : I.t -> string -> (#O.ctx, string option) Run.t

(** Information about a key stored in the database. Obviously, the key bytes are not
    available. *)
type info = <
  id : I.t ;
  hash : Hash.t ;
  ip : IpAddress.t ;
  time : Time.t ;
  enabled : bool ;
>

(** List all keys in the database. *)
val list : limit:int -> offset:int -> (#O.ctx, info list * int) Run.t
