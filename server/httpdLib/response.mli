(* © 2013 RunOrg *)

open Std

(** The status of a response. *)
type status = 
  [ `OK 
  | `BadRequest
  | `RequestEntityTooLarge 
  | `NotImplemented
  | `Unauthorized 
  | `NotFound
  | `Forbidden
  | `MethodNotAllowed 
  | `Accepted
  | `NotModified 
  | `ServiceUnavailable
  | `InternalServerError ]

(** A response. *)
type t

type time = float

(** Sends a response on a socket, then closes the socket. *)
val send : Ssl.socket -> t -> unit

(** Binds a response to a request. There are no semantic consequences 
    of doing so, beyond having the request-response pair appear in the 
    logs once the request is sent. *)
val for_request : time -> Request.t -> t -> t

(** Helper functions for creating responses. *)
module Make : sig

  (** An error response, formatted as JSON. *)
  val error : time -> status -> string -> t

  (** A response with a JSON payload. *)
  val json : ?headers:(string*string) list -> ?status:status -> Json.t -> t

  (** A response with raw payload. *)
  val raw : ?headers:(string*string) list -> ?status:status -> string -> t

  (** A 'try later' response. *)
  val tryLater : time -> int -> string -> t

end
