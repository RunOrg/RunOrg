(* © 2014 RunOrg *)

type error =   
  [ `Forbidden of string 
  | `BadRequest of string
  | `Unauthorized of string
  | `NotFound of string 
  | `Conflict of string
  | `InternalError of string
  ]

type 'a read_response = 
  [ `OK of 'a 
  | error
  | `WithJSON of Json.t * error ]

type 'a write_response = 
  [ 'a read_response | `Accepted of 'a ]

val respond_error : ?headers:string list -> Json.t option -> string -> error -> Httpd.response

val split : string -> string list

val respond : string -> ('a -> Json.t) -> [< 'a write_response] -> Httpd.response
