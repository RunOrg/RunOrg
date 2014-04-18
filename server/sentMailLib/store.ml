(* © 2014 RunOrg *)

open Std

include Cqrs.Stream(struct
  include Events
  let name = "sendmail"
end)
