(* © 2014 RunOrg *)

open Std

(* Canonical splitting: all non-empty segments. *)
let split path = 
  List.filter (fun s -> s <> "") (String.nsplit path "/") 
  
(* General response types
   ====================== *)

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

let respond_error ?headers more path what = 
  let status, error = match what with 
    | `Forbidden     error -> `Forbidden, error
    | `NotFound      error -> `NotFound,  error
    | `Unauthorized  error -> `Unauthorized, error
    | `BadRequest    error -> `BadRequest, error
    | `Conflict      error -> `Conflict, error
    | `InternalError error -> `InternalServerError, error
  in 
  let list = [ "error", Json.String error ; "path", Json.String path ] in
  let list = match more with None -> list | Some json -> ( "details", json ) :: list in
  Httpd.json ~status (Json.Object list) 

let respond path to_json = function 
  | `WithJSON (more,what) -> respond_error (Some more) path what   
  | `OK               out -> Httpd.json (to_json out)
  | `Accepted         out -> Httpd.json ~status:`Accepted (to_json out)
  | #error        as what -> respond_error None path what 

