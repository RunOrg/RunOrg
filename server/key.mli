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
