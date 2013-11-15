(* © 2013 RunOrg *)

(** Initializes the modules used internally for HTTPS, such as SSL. *)
val init : unit -> unit

(** Creates an SSL context to be used for all requests, using the server's
    listening socket. *)
val context : Unix.file_descr -> Common.config -> Ssl.context

(** Parse the request received on the specified socket, handle it using the
    handler, send back the generated response, and close the socket. *)
val parse : 
  Ssl.context -> Unix.file_descr -> Common.config -> 
  (Request.t -> ('ctx, Response.t) Run.t) ->
  ('ctx, unit) Run.t
