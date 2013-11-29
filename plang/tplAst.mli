(* © 2013 RunOrg *)

(** Abstract syntax tree for templates. *)

(** Supported comparison operators. *)
type comparison =  [ `Equal (* == *)
		   | `TypeEqual (* === *)
		   | `Lt 
		   | `Leq
		   | `Gt
		   | `Geq
		   | `NotEqual (* != *)
		   | `NotTypeEqual (* !== *)
		   ]

(** Expressions are means of extracting values from the template argument. *)
type expr = [ `Var of string
	    | `Dot of expr * string 
	    | `Nth of expr * expr
	    | `Int of int
	    | `Lit of string 
	    | `Null 
	    | `Self 
	    | `Not of expr
	    | `And of expr * expr
	    | `Or of expr * expr
	    | `Compare of expr * expr * comparison
	    ]

(** Internationalization value. The path refers to the 
    corresponding dot-separated identifier in an i18n file. 
    The optional argument expression is passed to the 
    internationalization function, if present. *)
class i18n : ?arg:expr -> string list -> object
  method path : string list
  method arg : expr option
end

(** A call to a sub-template renders that template. *)
class ['a] call : 
  ?arg: expr -> 
  ?first: 'a -> 
  ?more: (string * 'a) list ->
  string list -> 
object
  method path : string list
  method arg : expr option 
  method first : 'a option 
  method more : (string * 'a) list
end

(** A file is a list of individual, consecutive blocks (in the
    order they should be rendered). *)
type file = block list
  
(** A block is the basic unit of polymorphism. Each block is 
    responsible for rendering a bit of HTML. *)
and block = [ `HTML of string
	    | `Echo of expr
	    | `Call of file call
	    | `Sub  of expr  
	    | `I18n of i18n 
	    | `If   of expr * file * file option 
	    | `Each of expr * file 
	    | `Id   of expr ]
