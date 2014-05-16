(* © 2014 RunOrg *)

type role = [ `Run | `Reset ]

(** The path to the configuration used by this instance. By order of priority: 
    - The contents of the -config command-line argument. 
    - File ./conf.ini if it exists.
    - /etc/runorg/conf.ini 
*)
val path : string

(** The role of this instance, as parsed from the command line. *)
val role : role

(** Is this server running in test mode ? This would enable the "login as 
    test script" API endpoint. *)
val test : bool


module Log : sig

  (** If set, write logs to a file in that folder. Otherwise, write logs to 
      standard output. *)
  val prefix : string option

  (** Is the HTTPD log enabled ? RunOrg will always generate at least one line 
      per request, in access.log format. *)
  val httpd : [ `None | `Trace | `Debug ]

end

module Database : sig

  val host : string
  val port : int
  val database : string
  val user : string
  val password : string

  (** Database pool size. The number of connections kept around
      after being released, to skip the ~25ms connection time. *)
  val pool_size : int

end

(** The list of all super-administrator emails loaded from configuration. *)
val admins : string list

(** The full domain audience on which the admin UI runs. *)
val admin_audience : string

(** Default audience domains used when creating a database. *)
val default_audience : string list 

module Httpd : sig
  val port : int
  val key_path : string 
  val certificate_path : string
  val key_password : string
  val max_header_size : int
  val max_body_size : int
  val max_duration : float 
  val max_connections : int
end

(** The crypto key used to generate session values *)
val token_key : string

(** Configuration for the mailing module *)
module Mail : sig

  (** The base URL used to create links in e-mail bodies. *)
  val url : string
    
end
