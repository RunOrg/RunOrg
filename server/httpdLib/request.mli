(* © 2013 RunOrg *)

open Std

(** An error that can occur while parsing a request. *)
type error = 
  | HeaderTooLong
  | BodyTooLong
  | SyntaxError of string
  | NotImplemented of string
  | Timeout

(** All the information required to send back a compatible CORS response:
    - the extracted 'Origin:' header
    - a map of all headers in the request *)
type cors = string * (string, string) Map.t

type t = <
  host : string ; 
  client_ip : IpAddress.t ; 
  path : string list ; 
  verb : [ `GET | `PUT | `POST | `DELETE | `OPTIONS ] ;
  body : [ `JSON of Json.t | `Raw of string ] option ;
  headers : (string, string) Map.t ;
  params : (string, string) Map.t ;
  token : Token.I.t option ;
  at : Cqrs.Clock.t option ; 
  as_ : PId.t option ; 
  limit : int option ;
  offset : int option ; 
  content_type : string option ; 
  accept: [ `JSON | `MSGPACK ] ;
  origin : string option ;
> ;;

(** Parses a request. Attempts to determine the CORS context even if other aspects of
    parsing fail (so that a correct response may be sent to the right place). Does not
    raise exceptions. *)
val parse : Common.config -> Ssl.socket -> ('any, cors option * (t,error) result) Run.t

val to_string : t -> string
