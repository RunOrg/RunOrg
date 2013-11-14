open Camlp4.PreCast
open Syntax

(* [[    let! x = a in b    ]] *)

EXTEND Gram
    GLOBAL: expr;

    expr: LEVEL "top"
    [
      [ "let"; "!"; p = patt ; "=" ; e = expr ; "in" ; e' = expr ->
        <:expr< (Run.bind (fun $p$ -> $e'$) ($e$)) >> ] 
    ] ;

END;; 


(* [[    List.map (#name) people    ]] *)

EXTEND Gram 
    GLOBAL: expr;

    expr: LEVEL "simple" 
    [
      [ "#" ; i = LIDENT ->
        <:expr< (fun __obj -> __obj # $i$) >> ]  
    ] ;

END;;

(* [[    type json person = < name : string >    ]] *)

type id = Loc.t * string

type typemod = Loc.t * id list 

type typexpr = Loc.t * typedef
and typedef =
  [ `variant of < 
      label : id ;
      name  : id ;
      nth   : int ;
      typ   : typexpr list 
    > list
  | `record  of < 
      label   : id ;
      name    : id ;
      typ     : typexpr ;      
      default : Ast.expr option option ;
      mut     : bool 
    > list
  | `tuple of typexpr list
  | `string
  | `bool
  | `float
  | `int 
  | `unit
  | `self
  | `option of typexpr
  | `list   of typexpr
  | `array  of typexpr
  | `obj    of <
      label   : id ;
      name    : id ;
      typ     : typexpr ; 
      default : Ast.expr option option ;
      mut     : bool 
    > list
  | `poly of <
      label : id ; 
      name  : id ;
      nth   : int ;
      typ   : typexpr list
    > list 
  | `m of typemod
  ]

let def v = function 
  | None   -> v
  | Some v -> v

let loc   = fst
let ident = snd

let tn _loc i = <:ident< $"_t_" ^string_of_int i$ >>

let fresh = 
  let i = ref 0 in
  fun () -> incr i ; "_t_" ^ string_of_int !i

let number list = 
  let rec aux i = function [] -> [] | h :: t -> h i :: aux (i+1) t in
  aux 0 list

let unique list = 
  let list = List.map (fun a -> a # label) list in
  let list = List.sort (fun a b -> compare (ident a) (ident b)) list in
  let rec test = function
    | [] | [_] -> () 
    | a :: (b :: _ as t) -> 
      if ident a = ident b then 
	Loc.raise (loc a) (Failure "This label should be unique") ;
      test t
  in test list

let make_variant_bind ~name ?label ?(typ=[]) nth = object
    
  val nth = nth
  method nth = nth

  val label = def name label 
  method label = label 
    
  val name = name
  method name = name
    
  val typ = typ
  method typ = typ
    
end 

let make_poly_bind ~name ?label ?(typ=[]) nth = object

  val nth = nth
  method nth = nth
    
  val label = def name label 
  method label = label 
    
  val name = name
  method name = name
    
  val typ = typ
  method typ = typ
    
end

let make_member_bind ~mut ~name ?label ?default typ = object 
    
  val label = def name label 
  method label = label 
    
  val mut = mut
  method mut = mut
    
  val name = name
  method name = name
    
  val default = default
  method default  = default
    
  val typ = typ
  method typ = typ
    
end

let in_module what ((_loc,def):typemod) = 
  let rec aux = function
    | [] -> what
    | h :: t -> let _loc = fst h in
		<:ident< $uid:ident h$ . $aux t$ >> 
  in aux def
  
module Json = struct

  let error _loc text src = 
    let s = <:expr< $str:("Expecting " ^ text ^ ", found ")$ ^ Json.serialize $src$ >> in
    <:expr< raise (Json.Error ($s$)) >>
      
  (* Parses either an OCaml record, or an OCaml object, from a list
     of key-value pairs. *)
  let parse_record src recurse _loc fields build = 

    let error = error _loc in
    
    (* Each field is associated with a box and a temp-box. The temp-box is
       a reference filled during parsing (see 'set' below), and the box is 
       a normal variable defined after parsing but before building the 
       final value. *)
    let fields_and_boxes = List.map (fun field -> (fresh(),field)) fields in
    
    let set box value = <:expr< $lid:box$.val := Some $value$ >> in
    
    (* Matches a key named 'k', places a value named 'v' in the corresponding
       temp-box. *)
    let set_temp_box_for_named_field = 
      let cases = List.fold_left begin fun acc (box,field) -> 
	let value = recurse <:expr< v >> (field # typ) in
	let case = <:match_case< $str:snd (field # label)$ -> $set box value$ >> in
	<:match_case< $case$ | $acc$ >> 
      end <:match_case< _ -> () >> fields_and_boxes in 
      <:expr< match k with [ $cases$ ] >>
    in
  
    (* Reads a list of key-value pairs from list '_l_' and fills named fields
       with them. *)
    let set_all_temp_boxes = <:expr< List.iter (fun (k,v) -> $set_temp_box_for_named_field$) _l_ >> in
  
    (* The build expression reads values from all boxes (not temp-boxes) and 
       creates an OCaml object or OCaml record with them. *)
    let build = build fields_and_boxes in
    
    let fill_boxes_and_build = List.fold_left begin fun acc (box,field) -> 
      let temp_box = <:expr< $lid:box$.val >> in
      let real_box = <:patt< $lid:box$ >> in
      let default = match field # default with 
	| None -> error ("field \"" ^ (snd field # label) ^ "\"") src 
	| Some None -> <:expr< None >> 
	| Some (Some e) -> e
      in
      let box_contents = <:expr< match $temp_box$ with [ Some _t_ -> _t_ | None -> $default$ ] >> in
      <:expr< let $real_box$ = $box_contents$ in $acc$ >>
    end build fields_and_boxes in
  
    let parse_and_build = <:expr< let () = $set_all_temp_boxes$ in $fill_boxes_and_build$ >> in

    (* Define the temp-boxes first. *)
    let parse_and_build = List.fold_left begin fun acc (i,t) -> 
      let temp_box = <:patt< $lid:i$ >> in
      let empty_ref = <:expr< ref None >> in
      <:expr< let $temp_box$ = $empty_ref$ in $acc$ >>
    end parse_and_build fields_and_boxes in

    let ok   = <:match_case< Json.Object _l_ -> $parse_and_build$ >> in
    let nok  = <:match_case< _ -> $error "object" src$ >> in
    <:expr< match $src$ with [ $ok$ | $nok$ ] >>
      
  let generate_t_of_json _loc (def:typexpr) = 

    let error = error _loc in
            
    let rec recurse src ((_loc,def):typexpr) = match def with 
	
      | `string -> begin
	let ok = <:match_case< Json.String _s_ -> _s_ >> in
	let nok = <:match_case< _ -> $error "string" src$ >> in
	<:expr< match $src$ with [ $ok$ | $nok$ ] >>
      end
	
      | `bool -> begin 
	let ok = <:match_case< Json.Bool _b_ -> _b_ >> in
	let nok = <:match_case< _ -> $error "bool" src$ >> in
	<:expr< match $src$ with [ $ok$ | $nok$ ] >>
      end
	
      | `int -> begin 
	let ok = <:match_case< Json.Int _i_ -> _i_ >> in
	let nok = <:match_case< _ -> $error "int" src$ >> in
	<:expr< match $src$ with [ $ok$ | $nok$ ] >>
      end
	
      | `float -> begin 
	let ok = <:match_case< Json.Float _f_ -> _f_ >> in
	let ok' = <:match_case< Json.Int _i_ -> float_of_int _i_ >> in
	let nok = <:match_case< _ -> $error "float" src$ >> in
	<:expr< match $src$ with [ $ok$ | $ok'$ | $nok$ ] >>
      end
	
      | `unit -> <:expr< () >>
	
      | `self -> <:expr< t_of_json $src$ >>
	
      | `m m -> begin
	let f = in_module <:ident< of_json >> m in
	<:expr< $id:f$ $src$ >>
      end
	
      | `option t -> begin
	let r = recurse <:expr< _t_ >> t in
	let none = <:match_case< Json.Null -> None >> in
	let some = <:match_case< _t_ -> Some $r$ >> in
	<:expr< match $src$ with [ $none$ | $some$ ] >> 
      end 
	
      | `list t -> begin
	let r = recurse <:expr< _t_ >> t in
	let list = <:match_case< Json.Array _l_ -> List.map (fun _t_ -> $r$) _l_ >> in
	let fail = <:match_case< _ -> $error "list" src$ >> in
	<:expr< match $src$ with [ $list$ | $fail$ ] >>
      end 
	
      | `array t -> begin
	let r = recurse <:expr< _t_ >> t in
	let list = <:match_case< Json.Array _l_ -> Array.of_list (List.map (fun _t_ -> $r$) _l_) >> in
	let fail = <:match_case< _ -> $error "list" src$ >> in
	<:expr< match $src$ with [ $list$ | $fail$ ] >>
      end 
	
      | `tuple l -> begin 
	let l = List.map (fun t -> (fresh (),t)) l in
	let patt = List.fold_right begin fun (i,_) acc -> 
	  let id = <:patt< $lid:i$ >> in
	  <:patt< [ $id$ :: $acc$ ] >> 
	end l <:patt< [] >> in
	let patt = <:patt< Json.Array $patt$ >> in
	let expr = List.fold_right begin fun (i,t) acc -> 
	  let id = <:expr< $lid:i$ >> in
	  let t  = recurse id t in
	  <:expr< $t$, $acc$ >>
	end l <:expr< >> in
	let ok = <:match_case< $patt$ -> ($tup:expr$) >> in
	let nok = <:match_case< _ -> $error "tuple" src$ >> in
	<:expr< match $src$ with [ $ok$ | $nok$ ] >>
      end
	
      | `variant l -> begin
	
	let matches = List.fold_right begin fun v acc -> 
          let p = <:patt< $str:snd v#label$ >> in
	  let p = <:patt< Json.String $p$ >> in
          let m = match v # typ with 
	    | [] -> <:match_case< $p$ -> $uid:ident (v#name)$ >>
	    | list -> begin
	      let l = List.map (fun t -> (fresh (),t)) list in
	      let patt = List.fold_right begin fun (i,_) acc -> 
		let id = <:ident< $lid:i$ >> in
		<:patt< [ $id:id$ :: $acc$ ] >> 
	      end l <:patt< [] >> in
	      let patt = <:patt< Json.Array [ $p$ :: $patt$ ] >> in
	      let list = List.fold_left begin fun acc (i,t) -> 
		let id = <:expr< $lid:i$ >> in
		let t = recurse id t in
		<:expr< $acc$ $t$ >>
	      end <:expr< $uid:ident (v#name)$ >> l in
	      <:match_case< $patt$ -> $list$ >>			    
	    end
	  in
	  <:match_case< $m$ | $acc$ >>  		      
	end l <:match_case< _ -> $error "variant" src$ >> in
	<:expr< match $src$ with [ $matches$ ] >> 
      end 
	
      | `poly l -> begin
	
	let matches = List.fold_right begin fun v acc -> 
          let p = <:patt< $str:snd v#label$ >> in
	  let p = <:patt< Json.String $p$ >> in
          let m = match v # typ with 
	    | [] -> let e = <:expr< ` $ident (v#name)$ >> in
		    <:match_case< $p$ -> $e$ >>
	    | [t] -> begin
	      let patt = <:patt< Json.Array [ $p$ ; _t_ ] >> in
	      let expr = recurse <:expr< _t_ >> t in
	      let expr = <:expr< `$ident (v#name)$ $expr$ >> in
	      <:match_case< $patt$ -> $expr$ >>			    
	    end
	    | list -> begin
	      let l = List.map (fun t -> (fresh (),t)) list in
	      let patt = List.fold_right begin fun (i,_) acc -> 
		let id = <:ident< $lid:i$ >> in
		<:patt< [ $id:id$ :: $acc$ ] >> 
	      end l <:patt< [] >> in
	      let patt = <:patt< Json.Array [ $p$ ; Json.Array $patt$ ] >> in
	      let list = List.fold_right begin fun (i,t) acc -> 
		let id = <:expr< $lid:i$ >> in
		let t = recurse id t in
		<:expr< $t$, $acc$ >>
	      end l <:expr<  >> in
	      let expr = <:expr< `$ident (v#name)$ ( $tup:list$ ) >> in
	      <:match_case< $patt$ -> $expr$ >>			    
	    end 
	  in
	  <:match_case< $m$ | $acc$ >>  		      
	end l <:match_case< _ -> $error "variant" src$ >> in
	<:expr< match $src$ with [ $matches$ ] >> 
      end 
	
	
      | `record r -> begin
	parse_record src recurse _loc r begin fun l -> 
	  let fields = List.fold_left begin fun acc (i,t) ->
	    let bind = <:rec_binding< $lid:ident (t # name)$ = $lid:i$>> in
	    <:rec_binding< $acc$ ; $bind$ >>
	  end <:rec_binding< >> l in	 
	  <:expr< { $fields$ } >> 
	end
      end
	
      | `obj o -> begin 
	parse_record src recurse _loc o begin fun l ->
	  let fields = List.fold_left begin fun acc (i,t) -> 
	    let name = ident (t # name) in
	    let vbind = <:class_str_item< value $name$ = $lid:i$>> in
	    let mbind = <:class_str_item< method $lid:name$ = $lid:name$ >> in
	    <:class_str_item< $vbind$ ; $mbind$ ; $acc$ >>
	  end <:class_str_item< >> l in 
	  <:expr< object $fields$ end >> 
	end
      end
	
    in
    
    let b = 
      let e = recurse <:expr< _t_ >> def in
      let f = <:expr< fun _t_ -> $e$ >> in
      let b = <:ident< t_of_json >> in
      let p = <:patt< $id:b$ >> in
      <:binding< $p$ = $f$ >> 
    in
    
    <:str_item< value rec $b$ >> 
      
  let generate_json_of_t _loc (def:typexpr) = 
    
    let rec recurse src ((_loc,def):typexpr) = match def with 
	
      | `string -> <:expr< Json.String $src$ >>
      | `int    -> <:expr< Json.Int $src$ >>
      | `float  -> <:expr< Json.Float $src$ >>
      | `bool   -> <:expr< Json.Bool $src$ >>
      | `unit   -> <:expr< Json.Null >>
	
      | `self   -> <:expr< json_of_t $src$ >> 
	
      | `m m    -> begin 
	let f = in_module <:ident< to_json >> m in
	<:expr< $id:f$ $src$ >> 
      end
	
      | `option t -> begin 
	let r = recurse <:expr< _t_ >> t in
	let m_none = <:match_case< None   -> Json.Null >> in
	let m_some = <:match_case< Some _t_ -> $r$ >> in  
	let m = <:match_case< $m_none$ | $m_some$ >> in
	<:expr< match $src$ with [ $m$ ] >>
      end
	
      | `list t -> begin
	let r = recurse <:expr< _t_ >> t in
	let e_fun = <:expr< fun _t_ -> $r$ >> in
	<:expr< Json.Array (List.map $e_fun$ $src$) >> 
      end
	
      | `array t -> begin
	let r = recurse <:expr< _t_ >> t in
	let src = <:expr< Array.to_list $src$ >> in
	let e_fun = <:expr< fun _t_ -> $r$ >> in
	<:expr< Json.Array (List.map $e_fun$ $src$) >> 
      end 
	
      | `tuple l -> begin
	let l = List.map (fun t -> (fresh (),t)) l in
	let patt = List.fold_right begin fun (i,_) acc -> 
	  let id = <:patt< $lid:i$ >> in
	  <:patt< $id$ , $acc$ >> 
	end l <:patt< >> in
	let list = List.fold_right begin fun (i,t) acc -> 
	  let id = <:ident< $lid:i$ >> in
	  let id = <:expr< $id:id$ >> in
	  let t = recurse id t in
	  <:expr< [ $t$ :: $acc$ ] >>
	end l <:expr< [] >> in
	let bind = <:binding< ($tup:patt$) = $src$ >> in
	<:expr< let $bind$ in Json.Array $list$ >> 
      end 
	
      | `variant l -> begin 
	let matches = List.fold_right begin fun v acc -> 
          let e = <:expr< $str:snd v#label$ >> in
	  let e = <:expr< Json.String $e$ >> in
          let m = match v # typ with 
	    | [] -> <:match_case< $uid:ident (v#name)$ -> $e$ >>
	    | list -> begin
	      let l = List.map (fun t -> (fresh (),t)) list in
	      let patt = List.fold_left begin fun acc (i,_) -> 
		let id = <:ident< $lid:i$ >> in
		<:patt< $acc$ $id:id$ >> 
	      end <:patt< $uid:ident (v#name)$ >> l in
	      let list = List.fold_right begin fun (i,t) acc -> 
		let id = <:ident< $lid:i$ >> in
		let id = <:expr< $id:id$ >> in
		let t = recurse id t in
		<:expr< [ $t$ :: $acc$ ] >>
	      end l <:expr< [] >> in
	      let e = <:expr< [ $e$ :: $list$ ] >> in
	      <:match_case< $patt$ -> Json.Array $e$ >>			    
	    end
	  in
	  <:match_case< $m$ | $acc$ >>  		      
	end l <:match_case< >> in
	<:expr< match $src$ with [ $matches$ ] >> 
      end
	
      | `poly p -> begin
	let matches = List.fold_right begin fun v acc -> 
          let e = <:expr< $str:snd v#label$ >> in
	  let e = <:expr< Json.String $e$ >> in
          let m = match v # typ with 
	    | [] -> <:match_case< `$ident (v#name)$ -> $e$ >>
	    | [t] -> begin
	      let patt = <:patt< `$ident (v#name)$ _t_ >> in			  
	      let t = recurse <:expr< _t_ >> t in
	      let e = <:expr< [ $e$ ; $t$ ] >> in
	      <:match_case< $patt$ -> Json.Array $e$ >>			    
	    end
	    | list -> begin
	      let l = List.map (fun t -> (fresh (),t)) list in
	      let patt = List.fold_right begin fun (i,_) acc -> 
		let id = <:ident< $lid:i$ >> in
		<:patt< $id:id$ , $acc$ >> 
	      end l <:patt< >> in
	      let patt = <:patt< `$ident (v#name)$ $tup:patt$ >> in			  
	      let list = List.fold_right begin fun (i,t) acc -> 
		let id = <:ident< $lid:i$ >> in
		let id = <:expr< $id:id$ >> in
		let t = recurse id t in
		<:expr< [ $t$ :: $acc$ ] >>
	      end l <:expr< [] >> in
	      let e = <:expr< [ $e$ ; Json.Array $list$ ] >> in
	      <:match_case< $patt$ -> Json.Array $e$ >>			    
	    end
	  in
	  <:match_case< $m$ | $acc$ >>  		      
	end p <:match_case< >> in
	<:expr< match $src$ with [ $matches$ ] >> 
      end
	
      | `record r -> begin 
	let list = List.fold_right begin fun f acc -> 
	  let l = <:expr< $str:snd (f#label)$ >> in
	  let t = <:expr< $src$ . $lid:ident (f # name)$ >> in
	  let e = recurse t (f # typ) in
	  let e = <:expr< ($l$, $e$) >> in
	  <:expr< [ $e$ :: $acc$ ] >>
	end r <:expr< [] >> in
	<:expr< Json.Object $list$ >>
      end		       
	
      | `obj o -> begin 
	let list = List.fold_right begin fun f acc -> 
	  let l = <:expr< $str:snd (f#label)$ >> in
	  let t = <:ident< t >> in
	  let b = 
	    let b = <:expr< $src$ # $ident (f # name)$ >> in
	    let p = <:patt< $id:t$ >> in
	    <:binding< $p$ = $b$ >>
	  in
	  let e = 
	    let e = recurse <:expr< $id:t$ >> (f # typ) in
	    <:expr< let $b$ in $e$ >>
	  in
	  let e = <:expr< ($l$, $e$) >> in
	  <:expr< [ $e$ :: $acc$ ] >>
	end o <:expr< [] >> in
	<:expr< Json.Object $list$ >>
      end	
    in
    
    let b = 
      let e = recurse <:expr< _t_ >> def in
      let f = <:expr< fun _t_ -> $e$ >> in
      let b = <:ident< json_of_t >> in
      let p = <:patt< $id:b$ >> in
      <:binding< $p$ = $f$ >> 
    in
    
    <:str_item< value rec $b$ >> 

end

module Pack = struct

  let generate_unpack _loc (def:typexpr) = 

    let unpacker = fresh () in 

    let parse_record recurse _loc fields build = 

      let fields = List.map (fun field -> fresh (), field) fields in 
      let n = List.length fields in 
      
      let extract = List.fold_right begin fun (var,field) acc -> 
	<:expr< let $lid:var$ = $recurse field # typ$ in $acc$ >>
      end fields (build fields) in 

      <:expr< let () = Pack.Raw.expect_array $int:string_of_int n$ $lid:unpacker$ in $extract$ >>

    in 
            
    let rec recurse ((_loc,def):typexpr) = match def with 
	
      | `string -> <:expr< Pack.Unpack.string $lid:unpacker$ >>	
      | `bool -> <:expr< Pack.Unpack.bool $lid:unpacker$ >>
      | `int -> <:expr< Pack.Unpack.int $lid:unpacker$ >>	
      | `float -> <:expr< Pack.Unpack.float $lid:unpacker$ >>
      | `unit -> <:expr< Pack.Raw.expect_none $lid:unpacker$ >>
      | `self -> <:expr< unpack $lid:unpacker$ >>
	
      | `m m -> begin
	let f = in_module <:ident< unpack >> m in
	<:expr< $id:f$ $lid:unpacker$ >>
      end
	
      | `option t -> <:expr< Pack.Unpack.option (fun $lid:unpacker$ -> $recurse t$) $lid:unpacker$ >>	
      | `list t -> <:expr< Pack.Unpack.list (fun $lid:unpacker$ -> $recurse t$) $lid:unpacker$ >>     	
      | `array t -> <:expr< Array.of_list (Pack.Unpack.list (fun $lid:unpacker$ -> $recurse t$) $lid:unpacker$) >>
	
      | `tuple l -> begin 
	let l = List.map (fun t -> (fresh (),t)) l in
	let n = List.length l in 
	let tuple = List.fold_right begin fun (i,_) acc ->
	  <:expr< $lid:i$, $acc$ >>
	end l <:expr< >> in
	let bind = List.fold_right begin fun (i,t) acc -> 
	  <:expr< let $lid:i$ = $recurse t$ in $acc$ >>
	end l <:expr< ($tup:tuple$) >> in 
	<:expr< let () = Pack.Raw.expect_array $int:string_of_int n$ $lid:unpacker$ in $bind$ >>
      end
	
      | `variant l -> begin	
	let size = fresh() in 
	let matches = List.fold_right begin fun v acc -> 
          let patt = <:patt< $int:string_of_int v#nth$ >> in
	  let n = List.length v # typ in 
	  let expr = match v # typ with 
	    | [] -> <:expr< $uid:ident (v#name)$ >>
	    | list -> begin
	      let l = List.map (fun t -> (fresh (),t)) list in
	      let expr = List.fold_left begin fun acc (i,_) ->
		<:expr< $acc$ $lid:i$ >>
	      end <:expr< $uid:ident (v#name)$ >> l in
	      List.fold_right begin fun (i,t) acc -> 
		<:expr< let $lid:i$ = $recurse t$ in $acc$ >>
	      end l expr 
	    end
	  in
	  let expr = <:expr< let () = Pack.Raw.size_was $int:string_of_int n$ $lid:size$ in $expr$ >> in
	  let m = <:match_case< $patt$ -> $expr$ >> in
	  <:match_case< $m$ | $acc$ >>  		      
	end l <:match_case< n -> Pack.Raw.bad_variant n >> in
	<:expr< 
	  let $lid:size$ = Pack.Raw.open_array $lid:unpacker$ in 
	  match Pack.Unpack.int $lid:unpacker$ with [ $matches$ ] 
	>> 
      end 
	
      | `poly l -> begin
	let size = fresh() in 
	let matches = List.fold_right begin fun v acc -> 	  
          let patt = <:patt< $int:string_of_int v#nth$ >> in
	  let expr = match v # typ with 
	    | [ ] -> <:expr< let () = Pack.Raw.size_was 1 $lid:size$ in `$ident (v#name)$ >>
	    | [t] -> <:expr< let () = Pack.Raw.size_was 2 $lid:size$ in `$ident (v#name)$ $recurse t$ >>
	    | list -> begin 
	      let l = List.map (fun t -> (fresh (),t)) list in
	      let n = List.length l in 
	      let expr = List.fold_left begin fun acc (i,_) ->
		<:expr< $acc$ $lid:i$ >>
	      end <:expr< `$ident (v#name)$ >> l in
	      let expr = List.fold_right begin fun (i,t) acc -> 
		<:expr< let $lid:i$ = $recurse t$ in $acc$ >>
	      end l expr in	      
	      <:expr< 
	        let () = Pack.Raw.size_was 2 $lid:size$ in 
		let () = Pack.Raw.expect_array $int:string_of_int n$ $lid:unpacker$ in
		$expr$ 
	      >>
	    end 
	  in
	  <:match_case< $patt$ -> $expr$ | $acc$ >>
	end l <:match_case< n -> Pack.Raw.bad_variant n >> in
	<:expr< 
	  let $lid:size$ = Pack.Raw.open_array $lid:unpacker$ in 
	  match Pack.Unpack.int $lid:unpacker$ with [ $matches$ ] 
	>> 
      end 
		
      | `record r -> begin
	parse_record recurse _loc r begin fun l -> 
	  let fields = List.fold_left begin fun acc (i,t) ->
	    let bind = <:rec_binding< $lid:ident (t # name)$ = $lid:i$>> in
	    <:rec_binding< $acc$ ; $bind$ >>
	  end <:rec_binding< >> l in	 
	  <:expr< { $fields$ } >> 
	end
      end
	
      | `obj o -> begin 
	parse_record recurse _loc o begin fun l ->
	  let fields = List.fold_left begin fun acc (i,t) -> 
	    let name = ident (t # name) in
	    let vbind = <:class_str_item< value $name$ = $lid:i$>> in
	    let mbind = <:class_str_item< method $lid:name$ = $lid:name$ >> in
	    <:class_str_item< $vbind$ ; $mbind$ ; $acc$ >>
	  end <:class_str_item< >> l in 
	  <:expr< object $fields$ end >> 
	end
      end
	
    in

    let binding = 
      let func = <:expr< fun $lid:unpacker$ -> $recurse def$ >> in
      <:binding< unpack = $func$ >> 
    in
    
    <:str_item< value rec $binding$ >> 	

  let generate_pack _loc (def:typexpr) = 

    let packer = fresh() in

    let rec recurse src ((_loc,def):typexpr) = match def with 

      | `string -> <:expr< Pack.Pack.string $src$ $lid:packer$ >>
      | `int    -> <:expr< Pack.Pack.int $src$ $lid:packer$ >>
      | `float  -> <:expr< Pack.Pack.float $src$ $lid:packer$ >>
      | `bool   -> <:expr< Pack.Pack.bool $src$ $lid:packer$ >>
      | `unit   -> <:expr< Pack.Pack.none $lid:packer$ >>
	
      | `self   -> <:expr< pack $src$ $lid:packer$ >> 
	
      | `m m    -> begin 
	let f = in_module <:ident< pack >> m in
	<:expr< $id:f$ $src$ $lid:packer$ >> 
      end
	
      | `option t -> begin 
	let value = fresh() in
	let r = recurse <:expr< $lid:value$ >> t in
	let m_none = <:match_case< None   -> Pack.Pack.none $lid:packer$ >> in
	let m_some = <:match_case< Some $lid:value$ -> $r$ >> in  
	let m = <:match_case< $m_none$ | $m_some$ >> in
	<:expr< match $src$ with [ $m$ ] >>
      end
	
      | `list t -> begin
	let value = fresh() in
	let r = recurse <:expr< $lid:value$ >> t in
	let e_fun = <:expr< fun $lid:value$ $lid:packer$ -> $r$ >> in
	<:expr< Pack.Pack.list $e_fun$ $src$ >> 
      end
	
      | `array t -> begin
	let value = fresh() in
	let r = recurse <:expr< $lid:value$ >> t in
	let src = <:expr< Array.to_list $src$ >> in
	let e_fun = <:expr< fun $lid:value$ $lid:packer$ -> $r$ >> in
	<:expr< Pack.Pack.list $e_fun$ $src$ >> 
      end 
	
      | `tuple l -> begin
	let l = List.map (fun t -> (fresh (),t)) l in
	let n = List.length l in 
	let start = <:expr< Pack.Raw.start_array $int:string_of_int n$ $lid:packer$ >> in
	let save = List.fold_left begin fun acc (i,t) -> 
	  let r = recurse <:expr< $lid:i$ >> t in
	  <:expr< let () = $acc$ in $r$ >>
	end start l in 
	let patt = List.fold_right begin fun (i,_) acc -> 
	  let id = <:patt< $lid:i$ >> in
	  <:patt< $id$ , $acc$ >> 
	end l <:patt< >> in
	let bind = <:binding< ($tup:patt$) = $src$ >> in
	<:expr< let $bind$ in $save$ >> 
      end 
	
      | `variant l -> begin 
	let matches = List.fold_right begin fun v acc -> 
          let tag = <:expr< Pack.Pack.int $int:string_of_int v#nth$ $lid:packer$ >> in
          let m = 
	    let list = v # typ in
	    let l = List.map (fun t -> (fresh (),t)) list in
	    let patt = List.fold_left begin fun acc (i,_) -> 
	      let id = <:ident< $lid:i$ >> in
	      <:patt< $acc$ $id:id$ >> 
	    end <:patt< $uid:ident (v#name)$ >> l in
	    let n = List.length l in 	      
	    let start = <:expr< Pack.Raw.start_array $int:string_of_int n$ $lid:packer$ >> in
	    let start = <:expr< let () = $start$ in $tag$ >> in
	    let save = List.fold_left begin fun acc (i,t) -> 
	      let r = recurse <:expr< $lid:i$ >> t in
	      <:expr< let () = $acc$ in $r$  >>
	    end start l in 
	    <:match_case< $patt$ -> $save$ >>			    
	  in
	  <:match_case< $m$ | $acc$ >>  		      
	end l <:match_case< >> in
	<:expr< match $src$ with [ $matches$ ] >> 
      end
	
      | `poly p -> begin
	let matches = List.fold_right begin fun v acc -> 
          let tag = <:expr< Pack.Pack.int $int:string_of_int v#nth$ $lid:packer$ >> in
          let m = match v # typ with 
	    | [] -> 
              <:match_case< 
	        `$lid:ident (v#name)$ -> 
  	          let () = Pack.Raw.start_array 1 $lid:packer$ in 
		  $tag$ 
              >>
	    | [t] -> begin
	      let value = fresh() in 
	      let patt = <:patt< `$lid:ident (v#name)$ $lid:value$ >> in			  
	      let t = recurse <:expr< $lid:value$ >> t in
	      let save = <:expr< 
		let () = Pack.Raw.start_array 2 $lid:packer$ in
		let () = $tag$ in
		$t$ 
	      >> in
	      <:match_case< $patt$ -> $save$ >>			    
	    end
	    | list -> begin
	      let l = List.map (fun t -> (fresh (),t)) list in
	      let patt = List.fold_right begin fun (i,_) acc -> 
		let id = <:ident< $lid:i$ >> in
		<:patt< $id:id$ , $acc$ >> 
	      end l <:patt< >> in
	      let patt = <:patt< `$ident (v#name)$ $tup:patt$ >> in		
	      let n = List.length list in 
	      let start = <:expr< Pack.Raw.start_array $int:string_of_int n$ $lid:packer$ >> in
	      let save = List.fold_left begin fun acc (i,t) -> 		
		let id = <:expr< $lid:i$ >> in
		let t = recurse id t in
		<:expr< let () = $acc$ in $t$ >>
	      end start l in
	      let save = <:expr< 
		let () = Pack.Raw.start_array 2 $lid:packer$ in 		
		let () = $tag$ in
		$save$ 
	      >> in
	      <:match_case< $patt$ -> $save$ >>			    
	    end
	  in
	  <:match_case< $m$ | $acc$ >>  		      
	end p <:match_case< >> in
	<:expr< match $src$ with [ $matches$ ] >> 
      end
	
      | `record r -> begin 
	let n = List.length r in 
	let start = <:expr< Pack.Raw.start_array $int:string_of_int n$ >> in
	List.fold_left begin fun acc f -> 
	  let t = <:expr< $src$ . $lid:ident (f # name)$ >> in
	  let save = recurse t (f # typ) in
	  <:expr< let () = $acc$ in $save$ >>
	end start r
      end
	
      | `obj o -> begin 
	let n = List.length o in 
	let start = <:expr< Pack.Raw.start_array $int:string_of_int n$ $lid:packer$ >> in
	List.fold_left begin fun acc f -> 
	  let value = fresh() in
	  let bind = <:binding< $lid:value$ = $src$ # $ident (f # name)$ >> in
	  let save = recurse <:expr< $lid:value$ >> (f # typ) in
	  <:expr< let () = $acc$ in let $bind$ in $save$ >>
	end start o
      end	
    in

    let binding = 
      let value = fresh () in
      let body = recurse <:expr< $lid:value$ >> def in
      let func = <:expr< fun $lid:value$ $lid:packer$ -> $body$ >> in
      <:binding< pack = $func$ >> 
    in
    
    <:str_item< value rec $binding$ >> 	

end

(* Generate constructor functions 
   ============================== *)

let generate_constructors _loc (def:typexpr) = 

  let object_builder _loc ofields = 
    let o = List.fold_left begin fun acc f ->
      let name = ident (f # name) in
      let vbind = <:class_str_item< value $name$ = $lid:name$>> in
      let mbind = <:class_str_item< method $lid:name$ = $lid:name$ >> in
      <:class_str_item< $vbind$ ; $mbind$ ; $acc$ >>
    end <:class_str_item< >> ofields in	 
    <:expr< object $o$ end >>
  in

  let record_builder _loc rfields = 
    let r = List.fold_left begin fun acc f ->
      let bind = <:rec_binding< $lid:ident (f # name)$ = $lid:ident (f # name)$>> in
      <:rec_binding< $acc$ ; $bind$ >>
    end <:rec_binding< >> rfields in	 
    <:expr< { $r$ } >>
  in

  let bindings _loc fields result = 
    List.fold_left begin fun acc f -> 
      let patt = <:patt< ~ $ident (f # name)$ >> in
      <:expr< fun $patt$ -> $acc$ >>
    end result fields
  in

  let variant ctor tlist = 
    List.concat (List.map begin fun item ->
      let name = ident (item # name) in 
      match item # typ with
      | [ _loc, `obj o ] -> let e = object_builder _loc o in
			    let b = bindings _loc o <:expr< $ctor name$ $e$ >> in 		      
			    let n = String.uncapitalize name  in
			    [ <:str_item< value $lid:n$ = $b$ >> ]
      | [ _loc, `record r ] -> let e = record_builder _loc r in
			       let b = bindings _loc r <:expr< $ctor name$ $e$ >> in
			       let n = String.uncapitalize name in 
			       [ <:str_item< value $lid:n$ = $b$ >> ]
      | _ -> [] 
    end tlist) 
  in

  let poly_builder tlist = 
    variant (fun name -> <:expr< `$name$ >>) tlist 
  in

  let variant_builder tlist = 
    variant (fun name -> <:expr< $uid:name$ >>) tlist
  in

  let ctors = 
    match snd def with 
    | `obj     o -> [ let e = object_builder _loc o in 
		      let b = bindings _loc o e in		      
		      <:str_item< value make = $b$ >> ]
    | `record  r -> [ let e = record_builder _loc r in 
		      let b = bindings _loc r e in
		      <:str_item< value make = $b$ >> ]
    | `variant v -> variant_builder v
    | `poly    p -> poly_builder p 
    | _          -> [] 
  in

  List.fold_left (fun acc item -> <:str_item< $item$ ; $acc$ >>) <:str_item< >> ctors

(* Generate clean type definition 
   ============================== *)

let generate_type _loc (def:typexpr) = 
  
  let in_module ((_loc,def):typemod) =
    let rec aux = function 
      | []     -> <:ident< t >>
      | h :: t -> let _loc = fst h in
		  <:ident< $uid:ident h$ . $aux t$ >> 
    in aux def
  in
    
  let rec recurse (_loc,def) = match def with 

    | `bool   -> <:ctyp< bool >>
    | `string -> <:ctyp< string >>
    | `int    -> <:ctyp< int >>
    | `float  -> <:ctyp< float >>
    | `unit   -> <:ctyp< unit >>
    | `self   -> <:ctyp< t >>

    | `list   t -> <:ctyp< list $recurse t$ >>
    | `array  t -> <:ctyp< array $recurse t$ >>
    | `option t -> <:ctyp< option $recurse t$ >>

    | `m m -> <:ctyp< $id:in_module m$ >> 

    | `record r -> let l = List.fold_right begin fun field acc -> 

                     let _loc = loc (field # name) in
		     let name = ident (field # name) in

                     let t = recurse (field # typ) in
		     let t = if field # mut then <:ctyp< mutable $t$ >> else t in
		     let field = <:ctyp< $lid:name$ : $t$ >> in

		     <:ctyp< $field$; $acc$ >>

                   end r <:ctyp< >> in 
		   <:ctyp< { $l$ } >>
		     
    | `obj o -> let l = List.fold_right begin fun field acc -> 

                  let _loc = loc (field # name) in
		  let name = ident (field # name) in
		  
                  let t = recurse (field # typ) in
		  let field = <:ctyp< $lid:name$ : $t$ >> in
		  
		  <:ctyp< $field$; $acc$ >>
		    
                end o <:ctyp< >> in 
		<:ctyp< < $l$ > >>
		  
    | `tuple t -> let t = List.fold_right begin fun t acc -> 
                    <:ctyp< $recurse t$ * $acc$ >>
                  end t <:ctyp< >> in
		  <:ctyp< ( $tup:t$ ) >> 
		  
    | `variant v -> let l = List.fold_right begin fun ctor acc -> 
      
                      let _loc = loc (ctor # name) in
		      let name = ident (ctor # name) in
		      let ctor = match ctor # typ with 
			| [] -> <:ctyp< $uid:name$ >> 
			| l -> let l = List.map recurse l in
			       <:ctyp< $uid:name$ of $list:l$ >>
		      in 
		      <:ctyp< $ctor$ | $acc$ >>

                    end v <:ctyp< >> in 
		    <:ctyp< [ $l$ ] >>

    | `poly p -> let l = List.fold_right begin fun ctor acc -> 
      
                   let _loc = loc (ctor # name) in
		   let name = ident (ctor # name) in
		   let ctor = match ctor # typ with 
		     | [] -> <:ctyp< `$name$ >>
		     | [t] -> 
		       let t = recurse t in
		       <:ctyp< `$name$ of $t$ >>
		     | l -> 
		       let l = List.fold_right (fun t acc -> <:ctyp< $recurse t$ * $acc$ >>) l <:ctyp< >> in
		       let t = <:ctyp< ( $tup:l$ ) >> in
		       <:ctyp< `$name$ of $t$ >>
		   in 
		   <:ctyp< $ctor$ | $acc$ >>

                 end p <:ctyp< >> in 
		 <:ctyp< [ = $l$ ] >>

  in

  let dcl = Ast.TyDcl (_loc, "t", [], recurse def, []) in 
  <:str_item< type $dcl$ >>

(* Complete generation 
   =================== *)

let generate _loc def = 
  let typedef = generate_type _loc def in
  let to_json = Json.generate_json_of_t _loc def in
  let of_json = Json.generate_t_of_json _loc def in
  let pack = Pack.generate_pack _loc def in 
  let unpack = Pack.generate_unpack _loc def in 
  let constructors = generate_constructors _loc def in 
  let core = <:str_item< $typedef$ ; $to_json$ ; $of_json$ ; $pack$ ; $unpack$ ; $constructors$ >> in
  <:module_expr< struct module T = struct $core$ end ; include T ; include Fmt.Extend(T) ; end >>

(* Grammar rules for parsing
   ========================= *)

EXTEND Gram 
  GLOBAL: module_expr ;

  module_expr: LEVEL "top" [
    [ "type"; loc = [ "module" -> _loc ]; def = typedef -> 
      generate loc def ]      
  ];

  name: [ 
    [ s = LIDENT -> (_loc,s) ]
  ];

  string: [ 
    [ s = STRING -> (_loc,Camlp4.Struct.Token.Eval.string ~strict:() s) ] 
  ];

  typedef: [ 
    [ v = variant -> (_loc, `variant v)
    | r = record  -> (_loc, `record  r) 
    | e = typexpr  -> e ]
  ];
  
  variant: [ 
    [ OPT "|"; list = LIST1 variant_bind SEP "|" -> 
      let list = number list in unique list ; list ]
  ];

  of_type: [
    [ "of" ; list = LIST1 typexpr LEVEL "simple" SEP "*" -> list ] 
  ];

  variant_bind: [
    [ name = [ n = UIDENT -> (_loc,n) ]; label = OPT string ; typ = OPT of_type -> 
      (fun nth -> make_variant_bind ~name ?label ?typ nth) ] 
  ];  

  record: [ 
    [ "{"; list = record_members -> unique list ; list ]
  ];
      
  record_members: [ 
    [ m = member_bind ; "}" -> [m]
    | m = member_bind ; ";" ; "}" -> [m] 
    | h = member_bind ; ";" ; t = record_members -> h :: t
    ]
  ];

  default: [
    [ "="; e = expr LEVEL "apply" -> e ] 
  ];

  col_type: [
    [ ":"; t = typexpr -> t ]
  ]; 

  member_bind: [
    [ m = OPT "mutable"; name = name; label = OPT string; typ = col_type ->
      make_member_bind ~mut:false ~name ?label typ
    | m = OPT "mutable"; "?"; name = name; label = OPT string; typ = col_type; def = OPT default -> 
      make_member_bind ~mut:false ~name ?label ~default:def typ ]
  ];

  object_members: [ 
    [ m = member_bind ; ">" -> [m]
    | m = member_bind ; ";" ; ">" -> [m] 
    | h = member_bind ; ";" ; t = object_members -> h :: t
    ]
  ];

  typexpr: [
      "top" [
	h = typexpr; "*"; t = LIST1 typexpr LEVEL "simple" SEP "*" -> 
	(_loc, `tuple (h :: t)) 	
      ]
	
    | "simple" [
      
        LIDENT "string" -> (_loc,`string)
      | LIDENT "bool"   -> (_loc,`bool) 
      | LIDENT "float"  -> (_loc,`float) 
      | LIDENT "int"    -> (_loc,`int)
      | LIDENT "unit"   -> (_loc,`unit)
      | LIDENT "t"      -> (_loc,`self)
	
      | t = typexpr ; LIDENT "option" -> (_loc, `option t) 
      | t = typexpr ; LIDENT "list"   -> (_loc, `list t) 
      | t = typexpr ; LIDENT "array"  -> (_loc, `array t) 
            
      | "<"; m = object_members -> (_loc,`obj m) 
      
      | "("; t = typexpr; ")" -> t
      
      | "["; l = poly; "]" -> (_loc,`poly l)     

      | t = typemod -> (_loc,`m t) 
    ]
  ];

  poly_name: [
    [ "`"; name = [ `(LIDENT id|UIDENT id) -> (_loc,id) ] -> name ]
  ];

  poly_bind: [
    [ name = poly_name ; label = OPT string ; typ = OPT of_type -> 
      (fun nth -> make_poly_bind ~name ?label ?typ nth) ] 
  ];

  poly: [
    [ list = LIST1 poly_bind SEP "|" -> 
      let list = number list in unique list ; list ]
  ];

  typemod_sub: [
    [ LIDENT "t" -> []
    | u = [ u = UIDENT -> (_loc,u) ]; "."; s = typemod_sub -> u :: s ] 
  ];

  typemod: [
    [ u = [ u = UIDENT -> (_loc,u) ]; "."; s = typemod_sub -> (_loc, u::s)  ]
  ]; 

END;;
