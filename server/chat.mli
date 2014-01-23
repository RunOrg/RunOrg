(* © 2014 RunOrg *)

(** Chatrooms are sequences of messages. *)

module I : sig
  include Id.PHANTOM
end

(** Create a new chatroom. *)
val create : CId.t list -> Group.I.t list -> (#O.ctx, I.t * Cqrs.Clock.t) Run.t

(** Create a new private chatroom between two contacts. *)
val createPM : CId.t -> CId.t -> (#O.ctx, I.t * Cqrs.Clock.t) Run.t
