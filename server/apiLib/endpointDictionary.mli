(* © 2014 RunOrg *)

type verb
type action = Httpd.request -> (O.ctx, Httpd.response) Run.t

val add : verb -> string list -> unit

val get : action -> verb
val put : action -> verb 
val post : action -> verb 
val delete : action -> verb

val dispatch : action 
