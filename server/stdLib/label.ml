(* © 2014 RunOrg *)

open Common 

(* String cleanup function
   ======================= *)

let of_string_detailed str = 

  let n = String.length str in
  let nextUTF8 = nextUTF8 str in     
  let buffer = Buffer.create n in 
  
  let rec cleanup start i sp nbsp c = 
    if i = n then       
      if sp then 
	max 0 (c - 1) (* Trim all space at the end. *)
      else
	( Buffer.add_substring buffer str start (i - start) ; c )
    else
      let i2, utf8 = nextUTF8 i in 
      let space = match utf8 with 
	| 0x09 | 0x0A | 0x0D | 0xA0 | 0x2028 | 0x2029 | 0xFFFE | 0xFEFF -> true 
	| _ -> false in 
      let nbsp2 = utf8 = 0xA0 in
      if sp <> space then 
	if sp then begin 
	  (* Found a non-space character after a whitespace sequence *)
	  if start > 0 (* Trim all space at the front. *) then 
	    if nbsp then Buffer.add_string buffer "\xC2\xA0" else Buffer.add_char buffer ' ' ;
	  cleanup i i2 false false (c + 1)
	end else begin 
	  (* Found a whitespace character after a non-space sequence *)
	  Buffer.add_substring buffer str start (i - start) ;
	  cleanup i i2 true nbsp2 (c + 1)
	end
      else
	cleanup start i2 sp (nbsp || nbsp2) (if sp then c else (c + 1))
  in

  try let n = cleanup 0 0 true false 0 in
      if n = 0 then `Empty else
	if n >= 80 then `TooLong n else
	  `Ok (Buffer.contents buffer) 
  with BadUTF8 i -> `UTF8 i

(* Parser format (overload JSON loading)
   ===================================== *)

module S = type module (string)

include Fmt.Make(struct
  type t = string
  let pack = S.pack
  let unpack = S.unpack
  let json_of_t = S.to_json 

  let t_of_json json = 
    let s = S.of_json json in    
    match of_string_detailed s with 
    | `Ok s -> s
    | `Empty -> raise (Json.error "Empty label")
    | `UTF8 n -> raise (Json.error "Invalid UTF-8 at byte %d") 
    | `TooLong n -> raise (Json.error (Printf.sprintf "Label is %d code points long, only 80 allowed." n))

end)

(* Conversion functions 
   ==================== *)

let of_string str = 
  match of_string_detailed str with 
  | `Ok s -> Some s 
  | `Empty
  | `UTF8 _  
  | `TooLong _ -> None

let to_string lbl = lbl
