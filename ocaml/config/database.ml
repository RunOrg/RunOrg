
(* Configuration for the local development database. *)

let dev = Ohm.Cqrs.({
  cfg_host = "localhost" ;
  cfg_port = 5432 ;
  cfg_database = "dev" ;
  cfg_user = "dev" ;
  cfg_password = "dev" ;
})
