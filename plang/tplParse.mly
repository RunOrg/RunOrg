%{

  (** Creates the appropriate "call" node (detects if and each calls) *)
  let call p arg b = 
    if p = ["if"] then 
      let expr = match arg with Some expr -> expr | None -> `Self in
      match b with 
      | Some (ifTrue, []) -> `If (expr, ifTrue, None)
      | Some (ifTrue, ["else",ifFalse]) -> `If (expr, ifTrue, Some ifFalse)
      | _ -> failwith "'if' keyword is reserved"
    else if p = ["each"] then
      let expr = match arg with Some expr -> expr | None -> `Self in 
      match b with 
      | Some (block, []) -> `Each (expr, block) 
      | _ -> failwith "'each' keyword is reserved"
    else if p = ["case"] then 
      failwith "'case' keyword is reserved"
    else
      let first, more = match b with Some (first,more) -> Some first , Some more | None -> None, None in
      `Call (new TplAst.call ?arg ?first ?more p) 

%}

%start <TplAst.file> file

%token 
  BeginBlock BeginCall BeginEcho BeginI18n BeginSub 
  EndCall EndEcho EndI18n EndSub Eof
  And Or Not Dot Self
  OpenBracket OpenParen CloseBracket CloseParen
       
%token <string>
  Html Block Literal Name

%token <int>
  Int

%token <TplAst.comparison>
  Comparison 

%%

file: 
  | l = list(block) ; Eof { l }

block: 
  | h = Html { `HTML h }
  | BeginEcho ; e = expr ; EndEcho { `Echo e }
  | BeginSub  ; e = expr ; EndSub { `Sub e }
  | BeginI18n ; p = path ; arg = option(expr) ; EndI18n {`I18n (new TplAst.i18n ?arg p) }
  | BeginCall ; p = path ; arg = option(expr) ; b = callBlocks ; EndCall { call p arg b }

callBlocks:
  | { None }
  | BeginBlock ; f = file ; l = list(namedCallBlock) { Some (f, l) }

namedCallBlock:
  | n = Block ; f = file { (n,f) }

path: 
  | l = separated_nonempty_list(Dot,Name) { l }

expr: 
  | l = separated_nonempty_list(Or,expr2) { match l with 
    | [] -> assert false
    | h :: t -> List.fold_left (fun acc e -> `Or (acc,e)) h t }

expr2: 
  | l = separated_nonempty_list(And,expr3) { match l with 
    | [] -> assert false
    | h :: t -> List.fold_left (fun acc e -> `And (acc,e)) h t }

expr3: 
  | a = expr4 { a }
  | a = expr4 ; c = Comparison ; b = expr4 { `Compare (a,b,c) }

expr4:
  | a = expr5 { a } 
  | Not ; a = expr5 { `Not a }

expr5:
  | i = Int { `Int i }
  | s = Literal { `Lit s }
  | Self { `Self }
  | v = Name { if v = "null" then `Null else `Var v }
  | e = expr5 ; Dot ; m = Name { `Dot (e,m) }
  | e = expr5 ; OpenBracket ; i = expr ; CloseBracket { `Nth (e,i) }
  | OpenParen ; e = expr ; CloseParen { e }

