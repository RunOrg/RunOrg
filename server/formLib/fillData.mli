(* © 2014 RunOrg *)

(** Serializes field data as a string-to-JSON map. *)

open Std

include Fmt.FMT with type t = (Field.I.t, Json.t) Map.t
