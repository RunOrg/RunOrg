(* © 2013 RunOrg *)

include Id.PHANTOM

module Assert : sig 
  val server_admin : 'a id -> [`ServerAdmin] id 
  val admin : 'a id -> [`Admin] id 
end
