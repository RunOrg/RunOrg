(* © 2014 RunOrg *)

include type module 
  [ `NoSuchForm of I.t
  | `NoSuchField of I.t * Field.I.t
  | `MissingRequiredField of I.t * Field.I.t
  | `InvalidFieldFormat of I.t * Field.I.t * Field.Kind.t
  | `NoSuchOwner of I.t * FilledI.t 
  ]
