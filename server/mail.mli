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
  ?text:String.Rich.t ->
  ?html:String.Rich.t ->
  Access.Audience.t -> (#O.ctx, I.t * Cqrs.Clock.t) Run.t
