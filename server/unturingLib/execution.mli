(* © 2014 RunOrg *)

open Std
open Compiler

type input = { 
  inline : Json.t list ;
  this : Json.t ;
  context : (string,Json.t) Map.t ;
}

val template : html:bool -> script -> input -> string 
val filter : script -> input -> input 
