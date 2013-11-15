(* © 2013 RunOrg *)

open Std

(** A multiplexed HTTP server implementation. *)

(** A request, as received by the server, and passed to the handler. *)
type request = <

  host : string ; 

  (** The IP of the client who sent this request. *)
  client_ip : string ; 

  (** The path requested. [/foo/bar//quux/] becomes [["foo";"bar";"quux"]] *)
  path : string list ; 

  (** The HTTP verb. *)
  verb : [ `GET | `PUT | `POST | `DELETE ] ;

  (** The request body. [`JSON] is parsed if the method body was either 
      [application/json] or [application/x-msgpack] *)
  body : [ `JSON of Json.t | `Raw of string ] option ;

  (** The provided headers. *)
  headers : (string, string) Map.t ;

  (** The provided query string parameters. Unescaped. *)
  params : (string, string) Map.t ;

  (** The token parameter value, if any. *)
  token : string option ;

  (** The limit parameter value, if any. *)
  limit : int option ;

  (** The offset parameter value, if any. *)
  offset : int option ; 

  (** The [Content-Type:] header. *)
  content_type : string option ; 

  (** Whether the response should be formatted as JSON or MSGPACK. *)
  accept: [ `JSON | `MSGPACK ] ;

> ;;

(** A response. Should be returned by the handler. *)
type response

(** The type of an HTTP response status. *)
type status = 
  [ `OK 
  | `BadRequest
  | `RequestEntityTooLarge 
  | `NotImplemented ]

(** Responds with some JSON. Default status is [`OK]. *)
val json : ?status:status -> Json.t -> response

(** A handler is a function that responds to HTTP requests. 
    Handlers are run-tasks and are executed by the scheduler in the 
    main thread. *)
type 'ctx handler = request -> ('ctx, response) Run.t

type config = { 
  port: int ; 
  key_path : string ; 
  key_password : string ; 
  certificate_path : string ; 
  max_header_size : int ;
  max_body_size : int ; 
}

(** Start the server. Return a thread that executes all 
    requests received by the server. *)
val start : config -> 'ctx handler -> 'ctx Run.thread

