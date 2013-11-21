(* © 2013 RunOrg *)

(** The type of an API GET response. *)
type 'a read_response = 
  [ `OK of 'a 
  | `Forbidden of string 
  | `NotFound of string ]

(** The type of an API POST, PUT or DELETE response. *)
type 'a write_response = 
  [ 'a read_response | `Accepted of 'a ]

(** The type of a configuration module for a GET endpoint
    (at the server level) *)
module type GET_ARG = sig

  (** A format that is able to parse an array of arguments 
      extracted from the url. *)
  module Arg : Fmt.FMT

  (** A format that is able to generate the JSON to be sent back to the
      client. *)
  module Out : Fmt.FMT

  (** The string path. Any '{foo}' in the path will match an arbitrary 
      segment and will be provided to [Arg] for parsing. *)
  val path : string

  (** The response function. Starts with a request and argument and
      returns the corresponding result. *)
  val response : Httpd.request -> Arg.t -> (O.ctx, Out.t read_response) Run.t

end

(** Create a get endpoint. *)
module Get : functor(A:GET_ARG) -> sig end

(** The type of a configuration module for a POST endpoint
    (at the server level) *)
module type POST_ARG = sig

  (** A format that is able to parse an array of arguments 
      extracted from the url. *)
  module Arg : Fmt.FMT

  (** A format that is able to parse the JSON post body. *)
  module Post : Fmt.FMT

  (** A format that is able to generate the JSON to be sent back to the
      client. *)
  module Out : Fmt.FMT

  (** The string path. Any '{foo}' in the path will match an arbitrary 
      segment and will be provided to [Arg] for parsing. *)
  val path : string

  (** The response function. Starts with a request and argument and
      returns the corresponding result. *)
  val response : Httpd.request -> Arg.t -> Post.t -> (O.ctx, Out.t write_response) Run.t

end

(** Create a post endpoint. *)
module Post : functor(A:POST_ARG) -> sig end

(** Dispatch a request, generate a response. *)
val dispatch : Httpd.request -> (O.ctx, Httpd.response) Run.t

