(* © 2014 RunOrg *)

type owner = [ `ServerAdmin | `Person of (Id.t * PId.t) ]
val create : owner -> (# O.ctx, I.t) Run.t
val is_server_admin : I.t -> (# O.ctx, [`ServerAdmin] I.id option) Run.t
val is_person : I.t -> (# O.ctx, [`Auth] PId.id option) Run.t 
val can_be : I.t -> PId.t -> (# O.ctx, bool) Run.t

