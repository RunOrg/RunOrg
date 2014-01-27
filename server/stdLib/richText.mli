(* © 2014 RunOrg *)

(** An inline element: anything which is displayed within a 
    paragraph of text. *)
type inline = 
| Text of string
| Strong of inline list
| Emphasis of inline list
| Anchor of string * inline list

(** A block element: anything which takes up all space horizontally. *)
type block = 
| Paragraph of inline list
| UnorderedList of block list list
| OrderedList of block list list
| Blockquote of block list
| Heading of int * inline list

(** A rich text element is a list of blocks. *)
include Fmt.FMT with type t = block list 
	
