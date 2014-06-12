(* © 2014 RunOrg *)

(** Creation of SQL queries and extraction of their results. *)

(** {1 Queries}

    Strings of SQL with attached parameters. 
*)

(** Immutable representation of an SQL query. *)
type query 

(** An empty query. *)
val query : query 

(** Create a bit of query from a string. *)
val q : string -> query 

(** An escaped table or field name. *)
val e : string -> query

(** Concatenate a list of queries with a separator. *)
val implode : query -> query list -> query 

(** Concatenate a list of queries without a separator. *)
val concat : query list -> query 

(** {1 Scalar parameters}

    Individual values: a single string or number. 
*) 

(** A scalar parameter, used to fill in part of a query. *)
type scalar

(** Create a parameter from an integer. *)
val i : int -> scalar

(** Create a parameter from a string. *)
val s : string -> scalar

(** Create a parameter from a packed serialization result. *)
val pack : 'a Pack.packer -> 'a -> scalar 

(** Create a parameter from an identifier. *)
val id : Id.t -> scalar

(** {1 Vector parameters}

    Multiple values, used for 'IN' queries. 
*)

(** A vector parameter, used to fill in part of a query. *)
type vector 

(** Create a vector parameter from a list of scalars. *)
val l : ('a -> scalar) -> 'a list -> vector

(** Create a vector parameter from a sub-query. *)
val sub : query -> vector

(** {1 Compiling queries} *)

(** [let query, params, binary = compile q] returns [query] (the string to be
    passed to the database), [params] (the byte representation of all parameters
    in the query, at the correct positions) and [binary] (for each parameter, whether
    that parameter is binary). *)
val compile : query -> (string * string array * bool array) 
