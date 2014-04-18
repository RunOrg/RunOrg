(* © 2014 RunOrg *)

open Std

include UnturingLib.Compiler
include UnturingLib.Execution

(* Compiling the script when unserializing from JSON. 
   ================================================== *)

include Fmt.Make(struct

  include type module <
    script : string ;
    inline : Json.t list ;
  >

  let json_of_t t = 
    match t # script, t # inline with 
      | "$0", [Json.String s] -> Json.String s
      | _ -> to_json t 
      
  let t_of_json json =

    let t = match json with 
      | Json.String s -> make ~script:"$0" ~inline:[Json.String s]
      | json          -> of_json json 
    in

    let r = compile (t # script) (t # inline) in
    match r with 
    | `OK _ -> t
    | `SyntaxError (tok,l,c) -> let error = !! "Line %d, char %d: unexpected token %S" (l+1) (c+1) tok in
				raise (Json.Error ([], error)) 

end)
