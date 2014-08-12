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

(** Update an existing chatroom. *)
val update : 
  PId.t option ->
  subject:String.Label.t option Change.t ->
  custom:Json.t Change.t -> 
  audience:Access.Audience.t Change.t ->
  I.t -> (#O.ctx, [ `OK of Cqrs.Clock.t
		  | `NotFound of I.t
		  | `NeedAdmin of I.t ]) Run.t
     
(** Delete a chatroom (does not apply to private chatrooms). *)
val delete : PId.t option -> I.t -> (#O.ctx, [ `OK of Cqrs.Clock.t
					     | `NeedAdmin of I.t 
					     | `NotFound of I.t ]) Run.t

(** Post a new item to the chatroom. *)
val createPost : 
  I.t -> 
  PId.t -> 
  String.Rich.t -> 
  Json.t -> 
  PostI.t option -> (#O.ctx, [ `OK of PostI.t * Cqrs.Clock.t
			     | `NeedPost of I.t
			     | `PostNotFound of (I.t * PostI.t)
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
  root     : int option ; 
  last     : Time.t option ; 
  subject  : String.Label.t option ; 
  access   : Access.Set.t ;
  audience : Access.Audience.t option ; 
  custom   : Json.t ; 
  track    : bool ; 
>

(** Get short information about a chatroom. *)
val get : PId.t option -> I.t -> (#O.ctx, info option) Run.t

(** Get all chatrooms that a given person participates in. *)
val all_as : ?limit:int -> ?offset:int -> PId.t option -> (#O.ctx, info list) Run.t

(** A post *)
type post = <
  id       : PostI.t ;
  author   : PId.t ;
  time     : Time.t ;
  body     : String.Rich.t ;
  custom   : Json.t ;
  count    : int ; 
  track    : bool ; 
  sub      : post list ; 
>

(** Get posts from a chatroom, in reverse chronological order. *)
val list :
   PId.t option -> 
  ?depth:int -> 
  ?limit:int -> 
  ?offset:int -> 
  ?parent:PostI.t -> 
   I.t -> (#O.ctx, [ `OK of int * (post list)
		   | `NeedRead of info
		   | `NotFound of I.t ]) Run.t

(** Subscribe or unsubscribe to a chatroom (or one of its posts). *)
val track : 
   PId.t -> 
  ?unsubscribe:bool -> 
  ?under:PostI.t -> 
  I.t -> (#O.ctx, [ `OK 
		  | `NeedRead of I.t 
		  | `PostNotFound of I.t * PostI.t
		  | `NotFound of I.t ]) Run.t

(** An unread post (less information that normal post) *)
type unread = <
  chat   : I.t ;
  id     : PostI.t ;
  author : PId.t ;
  time   : Time.t ;
  body   : String.Rich.t ;
  custom : Json.t ; 
  count  : int ; 
>

(** List all unread posts for the specified user. *)
val unread : 
  PId.t option -> 
  ?limit:int -> 
  ?offset:int -> 
  PId.t -> (#O.ctx as 'ctx, [ `NeedAccess of Id.t
			    | `OK of < list : unread list ; erase : 'ctx Run.effect > ]) Run.t
  
(** Mark a set of posts as read within the specified chatroom.
    Does nothing for posts that are not currently "unread" or do not exist. *)
val markAsRead : 
  PId.t -> 
  I.t -> 
  PostI.t list -> (#O.ctx, [ `OK 
			   | `NotFound of I.t ]) Run.t

(** For internal use: drops all trackers on a chat and all unread posts on that chat.
    To be used as a last resort to clean up unread posts from a chat that is not visible to 
    the contact anymore. *)
val garbageCollectTracker : PId.t -> I.t -> #O.ctx Run.effect
