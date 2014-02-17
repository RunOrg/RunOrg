(* © 2014 RunOrg *)

open Common

(* Output is guaranteed to be ASCII *)
let collapse str = 

  let n    = String.length str in 
  let next = nextUTF8 str in
  let buf  = Buffer.create n in

  let rec loop i = 
    if i = n then () else 
      let i, c = next i in
      Buffer.add_char buf (match c with       

      (* ASCII *)

      | 0x27 
      | 0x2D -> '.'

      | i when i >= 0x41 && i <= 0x5A -> Char.chr (i + 0x20)

      | i when i >= 0x61 && i <= 0x7A || i >= 0x30 && i <= 0x39 -> Char.chr i      

      | i when i >= 0xC0 && i <= 0xC5 || i >= 0xE0 && i <= 0xE5 -> 'a'

      (* Latin - 1 *)

      | 0xC6 | 0xE6 -> Buffer.add_char buf 'a' ; 'e'

      | 0xC7 | 0xE7 -> 'c'

      | i when i >= 0xC8 && i <= 0xCB || i >= 0xE8 && i <= 0xEB -> 'e'

      | i when i >= 0xCC && i <= 0xCF || i >= 0xEC && i <= 0xEF -> 'i'

      | 0xD0 | 0xF0 -> 'd'

      | 0xD1 | 0xF1 -> 'n'

      | i when i >= 0xD2 && i <= 0xD6 || i >= 0xF2 && i <= 0xF6 -> 'o'
      | 0xD8 | 0xF8 -> 'o'

      | i when i >= 0xD9 && i <= 0xDC || i >= 0xF9 && i <= 0xFC -> 'u'

      | 0xDD | 0xFD | 0xFF -> 'y'

      | 0xDE | 0xFE -> Buffer.add_char buf 't' ; 'h'

      | 0xDF -> Buffer.add_char buf 's' ; 's'

      (* A few additional punctuation *)
	
      | 0x2019 -> '.' (* Apostrophe *)
      | 0x2012 | 0x2013 | 0x2014 -> '.' (* Dashes *)

      (* Todo: handle more unicode *)

      (* Other characters are dropped *)

      | _ -> ' ') ;
      loop i 
  in

  loop 0 ; Buffer.contents buf 

let index str =   
  let clean = collapse str in 
  BatList.sort_unique compare 
    (List.flatten 
       (List.map 
	  (fun s -> 
	    if s = "" then [] else 
	      match BatString.nsplit s "." with [x] -> [x] | l -> s :: l)
	  (BatString.nsplit clean " "))) 
	  
let for_prefix_search str = 
  let clean = collapse str in 
  match List.rev (BatString.nsplit clean " ") with 
  | [] -> [], ""
  | h :: t -> BatList.sort_unique compare t, h 
