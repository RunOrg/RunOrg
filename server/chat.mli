(* © 2014 RunOrg *)

open Std

(** Chatrooms are sequences of posts. *)

(** Access levels on a chatroom. *)
module Access : Access.T with type t = 
  [ `Admin    (** Can do everything *)
  | `Moderate (** Can remove posts. *)
  | `Write    (** Can write posts (and remove their own). *)
  | `Read     (** Can list and count posts. *)
  | `View     (** Knows that the chatroom exists *) ]

module I : sig
  include Id.PHANTOM
end

module PostI : sig
  include Id.PHANTOM
end

(** Create a new chatroom. *)
val create : 
   PId.t option -> 
  ?subject:String.Label.t -> 
  ?custom:Json.t ->
   Access.Audience.t -> (#O.ctx, [ `OK of I.t * Cqrs.Clock.t
				 | `NeedAccess of Id.t ]) Run.t

(** Delete a chatroom (does not apply to private chatrooms). *)
val delete : PId.t option -> I.t -> (#O.ctx, [ `OK of Cqrs.Clock.t
					     | `NeedAdmin of I.t 
					     | `NotFound of I.t ]) Run.t

(** Post a new item to the chatroom. *)
val createPost : 
  I.t -> 
  PId.t -> 
  String.Rich.t -> (#O.ctx, [ `OK of PostI.t * Cqrs.Clock.t
			    | `NeedPost of I.t
			    | `NotFound of I.t ]) Run.t

(** Delete an item in a chatroom. *)
val deletePost : 
  PId.t option ->
  I.t -> 
  PostI.t -> (#O.ctx, [ `OK of Cqrs.Clock.t
		      | `NeedModerate of I.t
		      | `PostNotFound of (I.t * PostI.t)
		      | `NotFound of I.t ]) Run.t

(** Short information about a chatroom. *)
type info = <
  id       : I.t ; 
  count    : int option ;
  last     : Time.t option ; 
  subject  : String.Label.t option ; 
  access   : Access.Set.t ;
  audience : Access.Audience.t option ; 
  custom   : Json.t ; 
>

(** Get short information about a chatroom. *)
val get : PId.t option -> I.t -> (#O.ctx, info option) Run.t

(** Get all chatrooms that a given person participates in. *)
val all_as : ?limit:int -> ?offset:int -> PId.t option -> (#O.ctx, info list) Run.t

(** A post *)
type post = <
  id : PostI.t ;
  author : PId.t ;
  time : Time.t ;
  body : String.Rich.t ;
>

(** Get posts from a chatroom, in reverse chronological order. *)
val list :
   PId.t option -> 
  ?limit:int -> 
  ?offset:int -> 
   I.t -> (#O.ctx, [ `OK of info * (post list)
		   | `NeedRead of info
		   | `NotFound of I.t ]) Run.t

