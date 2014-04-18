(* © 2014 RunOrg *)

open Std

(** UnTuring is the DSL used by RunOrg to describe data
    processing. Its design goals are easy generation (it will be the
    target of compilers), easy static analysis (to prove bounds on
    execution time and memory usage) and helpful primitives for processing
    data. 

    Current supported syntax : 
    
    {[
expr = <expr> ; <expr>
     | $<int>
     | <context>
     | <expr>.<field> 
     | <expr>[<int>]
    ]}
*)

(** A compiled script. Includes inline data. *)
type script 

(** Input data for a script. Writing the variable [foo] accesses field [foo]
      of this map. *)
type input = (string,Json.t) Map.t 

(** Compile a script. Includes a list of inline data accessed as [$<int>] in the script. *)
val compile : string -> Json.t list -> [ `OK of script | `SyntaxError of string * int * int ]

(** Run the script in template mode, generating a string that is either 
    properly escaped HTML or raw text. *)
val template : html:bool -> script -> input -> string 

(** Filter the script's input to keep only data that is actually used by 
    the script (to keep memory usage down). *)
val filter : script -> input -> input 
  
include Fmt.FMT with type t = <
  script : string ; 
  inline : Json.t list 
> 
