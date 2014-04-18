(* © 2014 RunOrg *)

type t = 
  | Inline  of int
  | This
  | Context of string
  | Member  of t * string
  | Index   of t * int
  | Flat    of t list 
