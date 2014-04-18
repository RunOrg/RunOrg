(* © 2014 RunOrg *)

(** The service that sends e-mail. Set here so that everything can invoke it. *)
val set_sender_service : Run.service -> unit

(** Invoke the sender service *)
val ping_sender_service : unit -> 'ctx Run.effect

