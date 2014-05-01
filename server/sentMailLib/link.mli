(* © 2014 RunOrg *)

(** Links and link roots. A typical link identifier is 27 
    characters long. With a 10-character domain, the full 
    size of a link URL is 66 characters. Not excellent, but
    at least it fits on one line in text mode. 

    {[
https://runorg.com/db/00000000000/link/111111111112222222222233344
    ]}
*)
    
(** Link roots are common prefixes of the link token that
    can be used to identify (uniquely!) an (mid,cid) pair.
    They are also random enough to be tampering-proof, by
    incorporating a [Token] inside. *)
module Root : sig
  include Fmt.FMT
  val make : I.t -> int -> t
end 

include Fmt.FMT

val to_string : t -> string

(** Create an URL pointing at a link in the current database. 
    [{config.mail.url}/db/{db}/link/{id}] *) 
val url : Id.t -> t -> Json.t

(** Create a link that redirects to the root mail's "self" 
    url (assuming one was configured). *)
val self  : Root.t -> t

(** Create a link that tracks the root mail's opening. *)
val track : Root.t -> t

(** Create a link that authenticates the mail's 'to' contact
    and redirects to the nth url in the mail. *)
val auth : Root.t -> int -> t

(** Create a link that redirects to the nth url in the mail. *)
val view : Root.t -> int -> t

(** Obtain the root of this link. *)
val root : t -> Root.t

(** Describe what this link is about. *)
val what : t -> [ `Self | `Track | `View of int | `Auth of int ]
