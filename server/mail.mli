(* © 2014 RunOrg *)

(** Outgoing mail, both individual and in mass. *)

(** The identifier of an e-mail. *)
module I : Id.PHANTOM

(** The audience of an e-mail. *)
module Access : Access.T with type t = 
  [ `Admin | `View ]

(** Create an e-mail. The sender is NOT optional. *)
val create : 
  from:CId.t -> 
  subject:string ->
  ?text:string ->
  ?html:string ->
  Access.Audience.t -> (#O.ctx, I.t * Cqrs.Clock.t) Run.t
