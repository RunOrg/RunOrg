module Json = struct

  type t = 
    | Null
    | Array of t list
    | Object of (string * t) list
    | Float of float
    | Int of int
    | Bool of bool
    | String of string	

  let to_string _ = "."

  exception Error of string

  let serialize json = ""

end

module Pack = struct

  module Pack = struct

    let int (i:int) _ = ()
    let string s _ = ()
    let float f _ = ()
    let bool b _ = ()
    let none _ = () 

  end

  module Raw = struct
    let start_array (n:int) _ = ()
    let expect_array (n:int) _ = ()
    let open_array _ = 0   
    let size_was (i:int) (s:int) = ()
    let expect_none _ = ()
    let bad_variant (i:int) = assert false
  end

  module Unpack = struct
    let int _ = 0
    let string _ = ""
    let float _ = 0.
    let bool _ = true
    let option f x = Some (f x)
  end 

end

module Fmt = struct
  module Extend = functor(T:sig end) -> struct end
end

module T = type module 
    [ `A 
    | `B of int 
    | `C of int * int 
    | `D of < a : int ; b : string ; c : float ; d : bool > 
    | `E of string option 
    | `F of unit ]
      
