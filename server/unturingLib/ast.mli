(* © 2014 RunOrg *)

type t = 
  | Inline  of Json.t
  | Context of string
  | Member  of t * string
  | Index   of t * int
  | Flat    of t list 
