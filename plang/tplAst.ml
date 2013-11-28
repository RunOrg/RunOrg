(* © 2013 RunOrg *)

type comparison =  [ `Equal (* == *)
		   | `TypeEqual (* === *)
		   | `Lt 
		   | `Leq
		   | `Gt
		   | `Geq
		   | `NotEqual (* != *)
		   | `NotTypeEqual (* !== *)
		   ]

type expr = [ `Var of string
	    | `Dot of expr * string 
	    | `Nth of expr * expr
	    | `Int of int
	    | `Lit of string 
	    | `Null 
	    | `Self 
	    ]

type cond = [ `Expr of expr
	    | `Not of cond
	    | `And of cond * cond
	    | `Or of cond * cond
	    | `Compare of expr * expr * comparison
	    ]

class i18n ?arg path = object

  val path : string list = path
  method path = path

  val arg : expr option = arg
  method arg = arg

end

class ['a] call ?arg ?first ?(more=[]) path = object

  val path : string list = path
  method path = path

  val arg : expr option = arg
  method arg = arg

  val first : 'a option = first
  method first = first

  val more : (string * 'a) list = more
  method more = more

end

type file = block list
and block = [ `HTML of string
	    | `Echo of expr
	    | `Call of file call
	    | `Sub  of expr  
	    | `I18n of i18n 
	    | `If   of cond * block * block option 
	    | `Each of expr * block 
	    | `Id   of expr ]
