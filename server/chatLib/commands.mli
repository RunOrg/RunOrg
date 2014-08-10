(* © 2014 RunOrg *)

open Std

val create : 
   PId.t option -> 
  ?subject:String.Label.t ->   
  ?custom:Json.t ->
   ChatAccess.Audience.t -> (#O.ctx, [ `OK of I.t * Cqrs.Clock.t
				     | `NeedAccess of Id.t ]) Run.t

val update : 
  PId.t option ->
  subject:String.Label.t option Change.t ->
  custom:Json.t Change.t -> 
  audience:ChatAccess.Audience.t Change.t ->
  I.t -> (#O.ctx, [ `OK of Cqrs.Clock.t
		  | `NotFound of I.t
		  | `NeedAdmin of I.t ]) Run.t

val delete : 
  PId.t option -> I.t -> (#O.ctx, [ `OK of Cqrs.Clock.t
				  | `NeedAdmin of I.t 
				  | `NotFound of I.t ]) Run.t

val createPost : 
  I.t -> 
  PId.t -> 
  String.Rich.t -> 
  Json.t ->
  PostI.t option -> (#O.ctx, [ `OK of PostI.t * Cqrs.Clock.t
			     | `NeedPost of I.t
			     | `PostNotFound of (I.t * PostI.t)
			     | `NotFound of I.t ]) Run.t

val deletePost : 
  PId.t option ->
  I.t -> 
  PostI.t -> (#O.ctx, [ `OK of Cqrs.Clock.t
		      | `NeedModerate of I.t
		      | `NotFound of I.t 
		      | `PostNotFound of (I.t * PostI.t) ]) Run.t

val track : 
   PId.t -> 
  ?unsubscribe:bool -> 
  ?under:PostI.t -> 
  I.t -> (#O.ctx, [ `OK 
		  | `NeedRead of info 
		  | `PostNotFound of I.t * PostI.t
		  | `NotFound of I.t ]) Run.t

val unread : PId.t option -> ?limit:int -> ?offset:int -> PId.t -> (#O.ctx, (I.t * PostI.t) list) Run.t

val markAsRead : 
  PId.t -> 
  I.t -> 
  PostI.t list -> (#O.ctx, [ `OK 
			   | `NotFound of I.t ]) Run.t

val garbageCollectTracker : PId.t -> I.t -> #O.ctx Run.effect
