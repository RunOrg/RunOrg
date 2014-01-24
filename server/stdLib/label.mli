(* © 2014 RunOrg *)

(** A label is a short UTF-8 string, no longer than 80 code points, and not empty.

    The label is always trimmed and cleaned up. Initial and final whitespace
    (understood as javascript's regex character \s) are dropped, all whitespace
    characters are turned into either normal or non-breaking spaces (depending on their
    nature) and multiple consecutive whitespace characters are turned into only one 
    (a normal space, or a non-breaking space if only non-breaking spaces are found). 

    Length tests occur after trimming and cleanup.

    Note that in JavaScript, [string.length] returns the size in an UTF16 encoding, 
    which is always greater than the number of code points. It is therefore acceptable
    to use [label.trim().replace('\s+',' ').length < 80] as a test on the maximum length 
    of the string.

    Since RunOrg uses UTF-8 encoding for labels, a label may be up to 320 bytes long.
*)

include Fmt.FMT

(** Attempt to create a label from a string. Return [None] if the string does not
    satisfy the requirements. *)
val of_string : string -> t option 

(** Returns the string representation of a label. *)
val to_string : t -> string 

