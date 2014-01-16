(* © 2013 RunOrg *)

type owner = [ `ServerAdmin | `Admin of (Id.t * CId.t) ]
val create : owner -> (# O.ctx, I.t) Run.t
val is_server_admin : I.t -> (# O.ctx, [`ServerAdmin] I.id option) Run.t
val is_admin : I.t -> (# O.ctx, [`Admin] I.id option) Run.t 
  
