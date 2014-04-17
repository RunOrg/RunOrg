(* © 2013 RunOrg *)

open Std

(** The header was longer than the maximum allowed size. *)
exception HeaderTooLong

(** The body was longer than the maximum allowed size. *)
exception BodyTooLong

(** A syntax error occured, see string for more information. *)
exception SyntaxError of string

(** The method (the argument of the exception) is not supported. *)
exception NotImplemented of string

(** Maximum wait time for an individual connection was exceeded. *)
exception Timeout

(** An HTTP request, parsed. *)
type t = <

  (** The host to which the request is addressed. From the [Host:] header. *)
  host : string ; 

  (** The IP of the client who sent this request. *)
  client_ip : IpAddress.t ; 

  (** The path requested. [/foo/bar//quux/] becomes [["foo";"bar";"quux"]] *)
  path : string list ; 

  (** The HTTP verb. *)
  verb : [ `GET | `PUT | `POST | `DELETE | `OPTIONS ] ;

  (** The request body. [`JSON] is parsed if the method body was either 
      [application/json] or [application/x-msgpack] *)
  body : [ `JSON of Json.t | `Raw of string ] option ;

  (** The provided headers. *)
  headers : (string, string) Map.t ;

  (** The provided query string parameters. Unescaped. *)
  params : (string, string) Map.t ;

  (** The token parameter value, if any. *)
  token : Token.I.t option ;

  (** The at parameter value, if any. *)
  at : Cqrs.Clock.t option ; 

  (** The as parameter, parsed as a [CId.t], if any. *)
  as_ : CId.t option ; 

  (** The limit parameter value, if any. *)
  limit : int option ;

  (** The offset parameter value, if any. *)
  offset : int option ; 

  (** The [Content-Type:] header. *)
  content_type : string option ; 

  (** Whether the response should be formatted as JSON or MSGPACK. *)
  accept: [ `JSON | `MSGPACK ] ;

> ;;

val parse : Common.config -> Ssl.socket -> ('any, t) Run.t

val to_string : t -> string
