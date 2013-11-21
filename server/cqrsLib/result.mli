(* © 2013 RunOrg *)

(** If the returned result contains a top-left cell, unpack that 
    cell with the provided unpacker. Otherwise, return [None]. *)
val unpack : Sql.raw_result -> 'a Pack.unpacker -> 'a option
