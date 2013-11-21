(* © 2013 RunOrg *)

type owner = [ `ServerAdmin ]
val create : owner -> (# O.ctx, I.t) Run.t
val is_server_admin : I.t -> (# O.ctx, [`ServerAdmin] I.id option) Run.t
