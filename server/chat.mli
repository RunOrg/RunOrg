(* © 2014 RunOrg *)

open Std

(** Chatrooms are sequences of posts. *)

module I : sig
  include Id.PHANTOM
end

module MI : sig
  include Id.PHANTOM
end

(** Create a new chatroom. *)
val create : ?subject:String.Label.t -> PId.t list -> GId.t list -> (#O.ctx, I.t * Cqrs.Clock.t) Run.t

(** Create a new public chatroom with a label. *)
val createPublic : String.Label.t option -> (#O.ctx, I.t * Cqrs.Clock.t) Run.t

(** Delete a chatroom (does not apply to private chatrooms). *)
val delete : I.t -> (#O.ctx, Cqrs.Clock.t) Run.t

(** Post a new item to the chatroom. *)
val post : I.t -> PId.t -> String.Rich.t -> (#O.ctx, MI.t * Cqrs.Clock.t) Run.t

(** Delete an item in a chatroom. *)
val deleteItem : I.t -> MI.t -> (#O.ctx, Cqrs.Clock.t) Run.t

(** Short information about a chatroom. *)
type info = <
  id : I.t ; 
  count : int ;
  last : Time.t ; 
  subject : String.Label.t option ; 
  people : PId.t list ;
  groups : GId.t list ;
  public : bool ; 
>

(** Get short information about a chatroom. *)
val get : I.t -> (#O.ctx, info option) Run.t

(** Get all chatrooms that a given person participates in. *)
val all_as : ?limit:int -> ?offset:int -> PId.t option -> (#O.ctx, info list) Run.t

(** An item. *)
type item = <
  id : MI.t ;
  author : PId.t ;
  time : Time.t ;
  body : String.Rich.t ;
>

(** Get items from a chatroom, in reverse chronological order. *)
val list : ?limit:int -> ?offset:int -> I.t -> (#O.ctx, item list) Run.t

