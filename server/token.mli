(* © 2014 RunOrg *)

(** Tokens are used to identify the user performing the request. *)

(** The type of a token string. *)
module I : sig
  include Id.PHANTOM
  module Assert : sig
    val server_admin : 'a id -> [`ServerAdmin] id 
    val person : 'a id -> [`Person] id 
  end
end

(** The owner of a token. Determines what the token is allowed to 
    do. *)
type owner = [ `ServerAdmin | `Person of (Id.t * PId.t) ]

(** Create a new token in the token store. The token will be flushed
    after 48 hours have elapsed, or when its destruction is requested. *)
val create : owner -> (# O.ctx, I.t) Run.t

(** Checks whether a token exists and is a server administrator. *)
val is_server_admin : I.t -> (# O.ctx, [`ServerAdmin] I.id option) Run.t

(** Check whether a token exists and is a person of the current database. *)
val is_person : I.t -> (# O.ctx, [`Auth] PId.id option) Run.t

(** Can a token impersonate the provided person ? *)
val can_be : I.t -> PId.t -> (# O.ctx, bool) Run.t
