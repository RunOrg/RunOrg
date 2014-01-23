(* © 2014 RunOrg *)

(** Chatrooms are sequences of messages. *)

module I : sig
  include Id.PHANTOM
end

(** Create a new chatroom. *)
val create : unit -> (#O.ctx, I.t * Cqrs.Clock.t) Run.t

