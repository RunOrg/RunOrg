(* © 2014 RunOrg *)

(** Library for manipulating words from a text. *)


(** Splits a string into searchable words. 

    A searchable word is in lowercase (for characters for which this
    has a meaning).  Lowercasing of ASCII characters is performed by
    OCaml using the current locale.

    Accented characters are converted to their conventional
    non-accented equivalent, where applicable. For instance, [é] will
    turn into [e].

    Word slicing occurs across non-letter characters: ["Hello,
    world!"]  is split into ["hello"] and ["world"].  Some non-letter
    characters are kept (apostrophes and hyphens) because they often
    end up in a search pattern. These are both cut ant non cut: ["I'm
    ever-so-happy about this"] is cut into ["i"], ["m"], ["i.m"], 
    ["ever"], ["so"], ["happy"], ["ever.so.happy"], ["about"], ["this"]. 
*)
val index : string -> string list 

