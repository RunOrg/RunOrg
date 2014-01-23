(* © 2014 RunOrg *)

(** Chatrooms are sequences of messages. *)

module I : sig
  include Id.PHANTOM
end

module MI : sig
  include Id.PHANTOM
end

(** Create a new chatroom. *)
val create : CId.t list -> Group.I.t list -> (#O.ctx, I.t * Cqrs.Clock.t) Run.t

(** Create a new private chatroom between two contacts. *)
val createPM : CId.t -> CId.t -> (#O.ctx, I.t * Cqrs.Clock.t) Run.t

(** Delete a chatroom (does not apply to private chatrooms). *)
val delete : I.t -> (#O.ctx, Cqrs.Clock.t) Run.t

(** Post a new item to the chatroom. *)
val post : I.t -> CId.t -> string -> (#O.ctx, MI.t * Cqrs.Clock.t) Run.t

(** Delete an item in a chatroom. *)
val deleteItem : I.t -> MI.t -> (#O.ctx, Cqrs.Clock.t) Run.t

(** Short information about a chatroom. *)
type info = <
  id : I.t ; 
  count : int ;
  contacts : CId.t list ;
  groups : Group.I.t list ;
>

(** Get short information about a chatroom. *)
val get : I.t -> (#O.ctx, info option) Run.t
