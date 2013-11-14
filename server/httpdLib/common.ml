(* © 2013 RunOrg *)

type request = unit
type response = unit

type 'ctx handler = request -> response -> ('ctx, response) Run.t

type config = { port: int ; key : string }
