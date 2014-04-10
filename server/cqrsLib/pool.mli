(* © 2014 RunOrg *)

open Common

val using : config -> (cqrs -> (#ctx as 'ctx)) -> ('ctx, 'a) Run.t -> ('any, 'a) Run.t
