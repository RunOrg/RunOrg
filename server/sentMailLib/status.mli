(* © 2014 RunOrg *)

include Fmt.FMT with type t = 
  [ `Preview
  | `Scheduled
  | `Sent
  | `Failed ]
