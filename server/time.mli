(* Ohm is © 2013 Victor Nicollet *)

include Fmt.FMT

module Tz : sig
  type t 
  val gmt : t
end

val now : unit -> t

val of_timestamp : float -> t
val to_timestamp : t -> float

val to_iso8601 : t -> string
val of_iso8601 : string -> t option 

val to_compact : t -> string
val of_compact : string -> t option 

(** Create a datetime.
    [datetime Tz.gmt year month day hour minute second] 
*)
val datetime : Tz.t -> int -> int -> int -> int -> int -> int -> t 

(** Create a date.
    [date year month day]
*)
val date : int -> int -> int -> t

val ymd : t -> int * int * int 

val hms : t -> (int * int * int) option 

val day_only : t -> t 

val min : t
val max : t 
