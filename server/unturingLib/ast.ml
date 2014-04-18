(* © 2014 RunOrg *)

type t = 
  | Inline  of int
  | This
  | Context of int
  | Member  of t * int
  | Index   of t * int
  | Flat    of t list 
