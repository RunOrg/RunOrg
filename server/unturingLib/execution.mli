(* © 2014 RunOrg *)

open Std
open Compiler

type input = (string,Json.t) Map.t 

val template : html:bool -> script -> input -> string 
val filter : script -> input -> input 
