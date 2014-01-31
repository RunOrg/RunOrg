(* © 2014 RunOrg *)

(* String cleanup function
   ======================= *)

exception BadUTF8 of int

let nextUTF8 str = 
  let n = String.length str in 
  fun i -> 
    if i = n then raise (BadUTF8 i) else
      let c = Char.code str.[i] in
      if c < 0x80 then 
	i + 1, c 
      else if c < 0xC0 then 
	raise (BadUTF8 i) 
      else if c < 0xE0 then
	if i + 1 = n then raise (BadUTF8 i) else
	  let c2 = Char.code str.[i+1] in
	  if c2 / 64 <> 2 then raise (BadUTF8 i) else
	    i + 2, (c mod 32) * 64 + (c2 mod 64) 
      else if c < 0xF0 then
	if i + 2 = n then raise (BadUTF8 i) else
	  let c2 = Char.code str.[i+1] in
	  let c3 = Char.code str.[i+2] in 
	  if c2 / 64 <> 2 then raise (BadUTF8 i) else
	    if c3 / 64 <> 2 then raise (BadUTF8 i) else
	      i + 3, ((c mod 16) * 64 + (c2 mod 64)) * 64 + (c3 mod 64) 
      else
	if i + 3 = n then raise (BadUTF8 i) else
	  let c2 = Char.code str.[i+1] in
	  let c3 = Char.code str.[i+2] in 
	  let c4 = Char.code str.[i+3] in 
	  if c2 / 64 <> 2 then raise (BadUTF8 i) else
	    if c3 / 64 <> 2 then raise (BadUTF8 i) else
	      if c4 / 64 <> 2 then raise (BadUTF8 i) else
		i + 4, (((c mod 8) * 64  + (c2 mod 64)) * 64 + (c3 mod 64)) * 64 + (c4 mod 64) 
  
