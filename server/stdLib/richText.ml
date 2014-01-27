(* © 2014 RunOrg *)

type inline = 
  | Text of string
  | Strong of inline list
  | Emphasis of inline list
  | Anchor of string * inline list

type block = 
  | Paragraph of inline list
  | UnorderedList of block list list
  | OrderedList of block list list
  | Blockquote of block list
  | Heading of int * inline list

type t = block list

(* To ensure backwards compatibility, the actual serialized types are 
   distinct from the public interface types. *)

module Inline = type module 
  | Text of int * int
  | Strong of t list
  | Emphasis of t list
  | Anchor of int * int * (t list)
  
module Block = type module 
  | Paragraph of Inline.t list
  | UnorderedList of t list list
  | OrderedList of t list list
  | Blockquote of t list
  | Heading of int * Inline.t list 

module Backend = type module <
  text : string ;
  root : Block.t list ;
>

(* Transformation between the real type and the underlying type. All the 
   text data is stored in a side buffer. *)

let rec bInline_of_inline buf = function 
  | Text str -> let s = Buffer.length buf in 
		let l = String.length str in 
		Buffer.add_string buf str ; 
		Inline.Text (s,l)
  | Strong i -> Inline.Strong (List.map (bInline_of_inline buf) i)
  | Emphasis i -> Inline.Emphasis (List.map (bInline_of_inline buf) i)
  | Anchor (href,i) -> let s = Buffer.length buf in 
		       let l = String.length href in 
		       Buffer.add_string buf href ; 
		       Inline.Anchor (s, l, List.map (bInline_of_inline buf) i)
			  
let rec bBlock_of_block buf = function 
  | Paragraph i -> Block.Paragraph (List.map (bInline_of_inline buf) i)
  | UnorderedList l -> Block.UnorderedList (List.map (List.map (bBlock_of_block buf)) l)
  | OrderedList l -> Block.OrderedList (List.map (List.map (bBlock_of_block buf)) l)
  | Blockquote b -> Block.Blockquote (List.map (bBlock_of_block buf) b)
  | Heading (n,i) -> Block.Heading (n, List.map (bInline_of_inline buf) i)

let b_of_t t = 
  let buf = Buffer.create 1024 in
  let root = List.map (bBlock_of_block buf) t in
  let text = Buffer.contents buf in 
  Backend.make ~text ~root

let rec inline_of_bInline txt = function 
  | Inline.Text (s,l) -> Text (String.sub txt s l)
  | Inline.Strong i -> Strong (List.map (inline_of_bInline txt) i)
  | Inline.Emphasis i -> Strong (List.map (inline_of_bInline txt) i)
  | Inline.Anchor (s,l,i) -> Anchor (String.sub txt s l, List.map (inline_of_bInline txt) i) 
		
let rec block_of_bBlock txt = function 
  | Block.Paragraph i -> Paragraph (List.map (inline_of_bInline txt) i)      
  | Block.UnorderedList l -> UnorderedList (List.map (List.map (block_of_bBlock txt)) l)
  | Block.OrderedList l -> OrderedList (List.map (List.map (block_of_bBlock txt)) l)
  | Block.Blockquote b -> Blockquote (List.map (block_of_bBlock txt) b)
  | Block.Heading (n,i) -> Heading (n, List.map (inline_of_bInline txt) i)

let t_of_b b = 
  List.map (block_of_bBlock (b # text)) (b # root) 

(* Forwarding the packing functions appropriately. *)

include Fmt.Extend(struct
  type t = block list
  let t_of_json json = t_of_b (Backend.of_json json)
  let json_of_t t = Backend.to_json (b_of_t t)
  let pack t = Backend.pack (b_of_t t) 
  let unpack r = t_of_b (Backend.unpack r)
end)
