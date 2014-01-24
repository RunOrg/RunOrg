(* © 2014 RunOrg *)

(** A rich text block is a long UTF-8 string that includes formatting tags. 

    Tags follow an XML-like syntax, but the parser has been kept intentionally 
    simple. Supported tags are: <h1> to <h6>, <strong>, <em>, <p>, <img src>, 
    <a href> and <blockquote>. 

    The intent is that a rich text block should be usable as-is for HTML rendering
    (at least, for the features that are supported by HTML rendering).

    Special escape sequences &amp; &lt; &gt; &quot; are also supported.

    Any other tags will be escaped. 
*)

include Fmt.FMT

(** Attempt to parse a string as a rich text block. Return [None] if the string
    does not satisfy the requirements. 

    Also, even if [let Some rich = Rich.of_string str], there is no guarantee
    that [Rich.to_string rich = str] (and indeed, the rich text block might 
    rename and reformat tags and whitespace. *)
val of_string : string -> t option

(** Returns the string representation of a rich text block. *)
val to_string : t -> string
