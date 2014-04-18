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
     | this
     | contact
     | <expr>.<field> 
     | <expr>[<int>]
    ]}
*)

(** A compiled script. *)
type script 

(** Input data for a script *)
type input = { 

  (** The data that was provided alongside the script. Accessed through [$<int>] syntax, 
      with [$1] being the first element. *)
  inline : Json.t list ;

  (** Data from the object hosting the script, such as an e-mail using a script for 
      templating. Available as [this] in the script. *)
  this : Json.t ;

  (** Additional data from the environment. Writing the variable [foo] accesses field [foo]
      of this map. *)
  context : (string,Json.t) Map.t ;

}

(** Compile a script. If an error occurs, returns [None]. *)
val compile : string -> script option 

(** Run the script in template mode, generating a string that is either 
    properly escaped HTML or raw text. *)
val template : html:bool -> script -> input -> string 

(** Filter the script's input to keep only data that is actually used by 
    the script (to keep memory usage down). *)
val filter : script -> input -> input 
