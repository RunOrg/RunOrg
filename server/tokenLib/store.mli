(* © 2014 RunOrg *)

type owner = [ `ServerAdmin | `Contact of (Id.t * CId.t) ]
val create : owner -> (# O.ctx, I.t) Run.t
val is_server_admin : I.t -> (# O.ctx, [`ServerAdmin] I.id option) Run.t
val is_contact : I.t -> (# O.ctx, [`Auth] CId.id option) Run.t 
  
