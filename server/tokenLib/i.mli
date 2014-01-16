(* © 2014 RunOrg *)

include Id.PHANTOM

module Assert : sig 
  val server_admin : 'a id -> [`ServerAdmin] id 
end
