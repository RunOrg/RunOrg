(* © 2014 RunOrg *)

open Std

type input = { 
  inline : Json.t list ;
  this : Json.t ;
  context : (string,Json.t) Map.t ;
}

let template ~html script input = ""
let filter script input = input 

