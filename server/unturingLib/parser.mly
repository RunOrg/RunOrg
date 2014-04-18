%{ 

 exception ParseError

%}

%start <Ast.t> script

%token <int>
  Int Inline 

%token <string>
  Name

%token 
  Semicolon BracketO BracketC Dot This EOF

%%

script:
  | l = separated_nonempty_list(Semicolon, expr) ; EOF { Ast.Flat l }

expr: 
  | i = Inline { Ast.Inline i }
  | e = expr ; BracketO ; i = Int ; BracketC { Ast.Index (e,i) }
  | e = expr ; Dot ; n = Name { Ast.Member (e,n) }
  | This { Ast.This }
  | n = Name { Ast.Context n }
  | error { raise ParseError }
