%{ 

%}

%start <Ast.t> script

%token <int>
  Int 

%token <int * Json.t>
  Inline

%token <string>
  Name

%token 
  Semicolon BracketO BracketC Dot EOF

%%

script:
  | l = separated_nonempty_list(Semicolon, expr) ; EOF { Ast.Flat l }

expr: 
  | i = Inline { Ast.Inline (snd i) }
  | e = expr ; BracketO ; i = Int ; BracketC { Ast.Index (e,i) }
  | e = expr ; Dot ; n = Name { Ast.Member (e,n) }
  | n = Name { Ast.Context n }
  | error { raise Parsing.Parse_error }
