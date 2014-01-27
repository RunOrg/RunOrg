(* © 2013 RunOrg *)

module Js = struct

  open Printf

  let render_raw_html h = 
    sprintf "this.raw(%S)" h 

  let echo expr = 
    sprintf "this.esc(%s)" expr

  let sub expr = 
    sprintf "(%s).call(this)" expr 

  let each expr body = 
    sprintf "(function(_a,_i){for(;_i<_a.length;++_i)(function(__){%s}).call(this,_a[_i])}).call(this,%s,0)"
      body expr 

  let i18n path = 
    sprintf "this.esc(i18n.%s)" (String.concat "." path)

  let i18n_arg expr path = 
    sprintf "this.esc(i18n.%s(%s))" (String.concat "." path) expr

  let id expr = 
    sprintf "this.id(%s)" expr

  let if_then expr ifTrue = 
    sprintf "if(%s){%s}" expr ifTrue

  let if_then_else expr ifTrue ifFalse = 
    sprintf "if(%s){%s}else{%s}" expr ifTrue ifFalse

  let call path arg blocks = 
    if blocks <> [] then
      sprintf "this[%S]({data:__,args:[%s],blocks:{%s}})"
	(String.concat "/" path)
	(match arg with None -> "" | Some expr -> expr)
	(String.concat "," (List.map (fun (k,v) -> sprintf "%S:function(__){%s}" k v) blocks))
    else
      sprintf "this[%S](%s)"
	(String.concat "/" path)
	(match arg with None -> "__" | Some expr -> expr)

end 
  
let compare = function 
  | `Equal -> "=="
  | `TypeEqual -> "==="
  | `Lt -> "<"
  | `Leq -> "<="
  | `Gt -> ">"
  | `Geq -> ">="
  | `NotEqual -> "!="
  | `NotTypeEqual -> "!=="

let rec expression = function 
  | `Var s -> "__." ^ s
  | `Dot (e,s) -> "(" ^ expression e ^ ")." ^ s
  | `Nth (e,v) -> "(" ^ expression e ^ ")[" ^ expression v ^ "]"
  | `Int i -> string_of_int i 
  | `Lit s -> Printf.sprintf "%S" s
  | `Null -> "null"
  | `Self -> "__"
  | `Not e -> "!(" ^ expression e ^ ")"
  | `And (a,b) -> "(" ^ expression a ^ ")&&(" ^ expression b ^ ")"
  | `Or (a,b) -> "(" ^ expression a ^ ")||(" ^ expression b ^ ")"
  | `Compare (a,b,c) -> "(" ^ expression a ^ ")" ^ compare c ^ "(" ^ expression b ^ ")"

let rec body ast = 
  String.concat ";" (List.map statement ast)

and statement = function 
  | `HTML html -> Js.render_raw_html html
  | `Echo expr -> Js.echo (expression expr)
  | `Sub  expr -> Js.sub (expression expr)
  | `I18n i18n -> (match i18n # arg with 
    | None      -> Js.i18n (i18n # path)
    | Some expr -> Js.i18n_arg (expression expr) (i18n # path))
  | `Id expr -> Js.id (expression expr)
  | `If (expr, ifTrue, ifFalse) -> (match ifFalse with 
    | None -> Js.if_then (expression expr) (body ifTrue)
    | Some ifFalse -> Js.if_then_else (expression expr) (body ifTrue) (body ifFalse))
  | `Each (expr, what) -> Js.each (expression expr) (body what)
  | `Call call -> let blocks = match call # first with None -> [] | Some b -> ("first",b) :: call # more in
		  let blocks = List.map (fun (k,v) -> k, body v) blocks in
		  let arg = match call # arg with None -> None | Some expr -> Some (expression expr) in
		  Js.call (call # path) arg blocks

(* Compiles an individual template to the JavaScript code that defines it. *)
let compile_template path ast = 
  let name = Filename.chop_extension (String.concat "/" path) in
  Printf.sprintf ",%S:function(__){%s}" name (body ast)

(* Generates the code that is inserted as "{{ TEMPLATES }}" into the builtins *)
let compile templates = 
  String.concat "" (List.map (fun (path,ast) -> compile_template path ast) templates) 
  
