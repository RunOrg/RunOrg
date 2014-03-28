(* © 2014 RunOrg *)

include Fmt.FMT with type t = 
  [ `NoSuchForm of I.t
  | `NoSuchField of I.t * Field.I.t
  | `MissingRequiredField of I.t * Field.I.t
  | `InvalidFieldFormat of I.t * Field.I.t * Field.Kind.t
  | `NoSuchOwner of I.t * FilledI.t 
  ]
