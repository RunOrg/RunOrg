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
  CId.t option -> 
  from:CId.t -> 
  subject:String.Label.t ->
  ?text:string ->
  ?html:String.Rich.t ->
  Access.Audience.t -> (#O.ctx, [ `NeedAccess of Id.t
				| `OK of I.t * Cqrs.Clock.t ]) Run.t

(** Information about an e-mail. *)
type info = <
  id : I.t ;
  from : CId.t ;
  subject : String.Label.t ;
  text : string option ;
  html : String.Rich.t option ;
  audience : Access.Audience.t ;
>

(** Get information about an e-mail by identifier. *)
val get : I.t -> (#O.ctx, info option) Run.t
