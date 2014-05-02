(* © 2014 RunOrg *)

open Std

(** Outgoing mail, both individual and in mass. *)

(** The identifier of an e-mail. *)
module I : Id.PHANTOM

(** The audience of an e-mail. *)
module Access : Access.T with type t = 
  [ `Admin | `View ]

(** Create an e-mail. The sender is NOT optional. *)
val create : 
  PId.t option -> 
  from:PId.t -> 
  subject:Unturing.t ->
  ?text:Unturing.t ->
  ?html:Unturing.t ->
  ?custom:Json.t ->
  ?urls:String.Url.t list -> 
  ?self:(I.t -> String.Url.t) -> 
  Access.Audience.t -> (#O.ctx, [ `NeedAccess of Id.t
				| `NeedViewProfile of PId.t 
				| `OK of I.t * Cqrs.Clock.t ]) Run.t

(** Information about an e-mail. *)
type info = <
  id : I.t ;
  from : PId.t ;
  subject : Unturing.t ;
  text : Unturing.t option ;
  html : Unturing.t option ;
  audience : Access.Audience.t ;
  custom : Json.t ;
  urls : String.Url.t list ; 
  self : String.Url.t option ; 
>

(** Get information about an e-mail by identifier. *)
val get : I.t -> (#O.ctx, info option) Run.t
