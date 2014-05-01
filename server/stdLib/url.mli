(* © 2014 RunOrg *)

(** An URL is a string that follows a specific format. *)

include Fmt.FMT

val of_string : string -> t option 

val to_string : t -> string

(** [of_string_template "id" "http://domain/path/{id}"] is a function that takes
    a string parameter [foo] and returns the URL [http://domain/path/foo]. *)
val of_string_template : string -> string -> (string -> t) option  

(** Add a query string parameter to the URL. *)
val add_query_string_parameter : string -> string -> t -> t
