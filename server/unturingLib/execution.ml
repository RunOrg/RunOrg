(* © 2014 RunOrg *)

open Std

type input = { 
  this : Json.t ;
  context : (string,Json.t) Map.t ;
}

let template ~html script input = ""
let filter script input = input 

