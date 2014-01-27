(* © 2014 RunOrg *)

open RichText
open Buffer

let of_string_detailed str = 
  RichParse.parse RichLex.block str

let of_string str = 
  try Some (of_string_detailed str) with RichParse.ParseError _ -> None

let escape buf s = 
  let b = ref 0 in
  let len = String.length s in
  for m = 0 to len - 1 do
    match s.[m] with
    | '<' -> let () = add_substring buf s !b (m - !b) in
             let () = add_string buf "&lt;" in
             b := m+1
    | '>' -> let () = add_substring buf s !b (m - !b) in
             let () = add_string buf "&gt;" in
             b := m+1
    | '&' -> let () = add_substring buf s !b (m - !b) in
             let () = add_string buf "&amp;" in
             b := m+1
    | '"' -> let () = add_substring buf s !b (m - !b) in
             let () = add_string buf "&quot;" in
             b := m+1
    | _ -> ()
  done ;
  if !b < len then
    add_substring buf s !b (len - !b)

let to_string rich = 
  let buf = create 1024 in
  let rec inline = function 
    | Text t -> escape buf t
    | Strong i -> add_string buf "<strong>" ;
                  List.iter inline i ;
		  add_string buf "</strong>" 
    | Emphasis i -> add_string buf "<em>" ;
                    List.iter inline i ;
		    add_string buf "</em>" 
    | Anchor (href, i) -> add_string buf "<a href=\"" ;
                          escape buf href ;
			  add_string buf "\">" ;
			  List.iter inline i ;
			  add_string buf "</a>" 
  and block = function
    | Paragraph i -> add_string buf "<p>" ;
                     List.iter inline i ;
		     add_string buf "</p>" 
    | UnorderedList l -> add_string buf "<ul>" ;
                         List.iter (fun b -> 
			   add_string buf "<li>" ;
			   List.iter block b ;
			   add_string buf "</li>") l ;
			 add_string buf "</ul>" 
    | OrderedList l -> add_string buf "<ol>" ;
                       List.iter (fun b -> 
			 add_string buf "<li>" ;
			 List.iter block b ;
			 add_string buf "</li>") l ;
		       add_string buf "</ol>" 
    | Blockquote b -> add_string buf "<blockquote>" ;
                      List.iter block b ;
		      add_string buf "</blockquote>" 
    | Heading (n,i) -> add_string buf ("<h"^string_of_int n^">") ;
                       List.iter inline i ;
		       add_string buf ("</h"^string_of_int n^">") 
  in
  List.iter block rich ;
  contents buf 

(* The format forwarding : single JSON string for JSON formatting, complex and clean tree 
   representation for packing. *)

include Fmt.Make(struct
  type t = RichText.t
  let pack = RichText.pack
  let unpack = RichText.unpack 
  let json_of_t t = Json.String (to_string t) 
  let t_of_json = function 
    | Json.String str -> begin 
      try of_string_detailed str 
      with RichParse.ParseError (char, what) -> raise (Json.error (Printf.sprintf "At char %d: %s" char what))
    end
    | _ -> raise (Json.error "Expected rich text (as a JSON string)")
end)
