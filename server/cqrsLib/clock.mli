include Fmt.FMT

type stream = int

(** An empty vector clock : does not track any streams. *)
val empty : t

(** Is a vector clock empty (void of constraints) ? *)
val is_empty : t -> bool

(** A one-stream vector clock : marks the stream as being at the
    specified revision. *)
val at : stream -> int -> t

(** Merge two clocks. If a stream is referenced by both clocks, the
    highest revision number if kept. *)
val merge : t -> t -> t 

(** Are all the streams in the first clock at an earlier revision 
    number than those in the second clock ? If the second clock does not
    contain a revision for a stream, assume that it is later. *)
val earlier_than_constraint : t -> t -> bool 

(** As [earlier_than_constraint], but streams missing from the
    second clock are assumed to be at revision -1. *)
val earlier_than_checkpoint : t -> t -> bool

(** Gets the clock revision for a stream. *)
val get : t -> stream -> int option
