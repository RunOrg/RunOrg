open Char

type input  = { i_buf : string ; mutable i_pos : int }
type output = Buffer.t

exception Error of string
let fail message = raise (Error message)

module Pack = struct

  type t = output
  type 'a packer = 'a -> t -> unit

  let byte t i = Buffer.add_char t (chr i)

  let u8 t i = Buffer.add_char t (chr (i land 0xFF)) 
  let u16 t i = u8 t (i lsr 8) ; u8 t i 
  let u32 t i = u16 t (i lsr 16) ; u16 t i

  let s8 t i = u8 t (if i < 0 then i + 0x100 else i)
  let s16 t i = u16 t (if i < 0 then i + 0x10000 else i)
  let s32 t i = s16 t (i lsr 16) ; u16 t i 

  let int i t = 
    if i >= 0 then
      if i <= 0x7F then byte t i 
      else if i <= 0xFF then ( byte t 0xCC ; u8 t i )
      else if i <= 0xFFFF then ( byte t 0xCD ; u16 t i )
      else ( byte t 0xCE ; u32 t i ) 
    else
      if i >= - 0x20 then byte t (i + 0x100)
      else if i >= -0x80 then ( byte t 0xD0 ; s8 t i )
      else if i >= -0x8000 then ( byte t 0xD1 ; s16 t i )
      else ( byte t 0xD2 ; s32 t i )

  let string s t = 
    let l = String.length s in 
    let () = 
      if l <= 0x1F then byte t (0xA0 + l) 
      else if l <= 0xFF then (byte t 0xD9 ; u8 t l)
      else if l <= 0xFFFF then (byte t 0xDA ; u16 t l)
      else (byte t 0xDB ; u32 t l)
    in
    Buffer.add_string t s 

  let start_array l t = 
    if l <= 0xF then u8 t (0x90 + l)
    else if l <= 0xFFFF then (u8 t 0xDC ; u16 t l)
    else (u8 t 0xDD ; u32 t l)
    
  let list f list t = 
    start_array (List.length list) t ;
    List.iter (fun x -> f x t) list

  let map fk fv map t = 
    let l = List.length map in 
    let () = 
      if l <= 0xF then byte t (0x80 + l)
      else if l <= 0xFFFF then (byte t 0xDE ; u16 t l)
      else (byte t 0xDF ; u32 t l)
    in
    List.iter (fun (k,v) -> fk k t ; fv v t) map

  let none t = byte t 0xC0

  let bool b t = 
    byte t (if b then 0xC3 else 0xC2) 

  let option f opt t = 
    match opt with 
    | None -> none t 
    | Some x -> f x t 

  let float f t = 
    byte t 0xCB ; 
    let open Int64 in 
    let f = of_float f in 
    let rec r i = 
      if i <= 4 then 
	(u16 t (to_int (shift_right_logical f ((4-i)*16))) ; r (i+1))
    in r 1

end

module Unpack = struct

  type t = input
  type 'a unpacker = t -> 'a

  let fwd i bytes = 
    i.i_pos <- i.i_pos + bytes ;
    if i.i_pos > String.length i.i_buf then 
      fail (Printf.sprintf "Truncated pack at length %d" (String.length i.i_buf))

  let u8 b p = code b.[p]
  let u16 b p = ((u8 b p) lsl 8) + (u8 b (p+1))
  let u32 b p = 
    let open Int32 in 
    let top = of_int (u16 b p) and bot = of_int (u16 b (p+2)) in
    to_int (add (shift_left top 16) bot) 

  let s8 b p = let i = u8 b p in if i > 0x7F then i - 0x100 else i 
  let s16 b p = let i = u16 b p in if i > 0x7FFF then i - 0x10000 else i 
  let s32 b p = u32 b p 

  let f32 b p = 
    let open Int32 in 
    let w0 = of_int (u16 b p) and w1 = of_int (u16 b (p+2)) in
    to_float (add (shift_left w0 16) w1)

  let f64 b p = 
    let open Int64 in
    let rec combine i s = 
      if i = 8 then s else 
	combine (i+1) (add (shift_left s 8) (of_int (code b.[p+i])))
    in
    to_float (combine 0 zero)

  let int i =
    let b = i.i_buf and p = i.i_pos in 
    match code b.[p] with 
    | 0xCC -> fwd i 2 ; u8 b (p+1)
    | 0xCD -> fwd i 3 ; u16 b (p+1)
    | 0xCE -> fwd i 5 ; u32 b (p+1) 
    | 0xCF -> fail "UINT64 not supported"
    | 0xD0 -> fwd i 2 ; s8 b (p+1)
    | 0xD1 -> fwd i 3 ; s16 b (p+1)
    | 0xD2 -> fwd i 5 ; s32 b (p+1)
    | 0xD3 -> fail "INT64 not supported"
    | x when x >= 0xE0 -> fwd i 1 ; x - 0x100
    | x when x <= 0x7F -> fwd i 1 ; x
    | x -> fail (Printf.sprintf "Expected integer, found: 0x%X at position %d" x p)

  let map k v i = 

    let rec long n acc = 
      if n = 0 then List.rev acc else 
	let _k = k i in
	let _v = v i in
	long (n-1) ((_k,_v) :: acc)
    in 

    let rec short n = 
      if n = 0 then [] else
	let _k = k i in 
	let _v = v i in 
	(_k, _v) :: short (n-1)
    in

    let b = i.i_buf and p = i.i_pos in 
    match code b.[p] with 
    | 0xDE -> fwd i 3 ; long (u16 b (p+1)) [] 
    | 0xDF -> fwd i 5 ; long (u32 b (p+1)) []
    | x when x >= 0x80 && x <= 0x8F -> fwd i 1 ; short (x - 0x80)
    | _ -> fail "Expected map"

  let float i = 
    let b = i.i_buf and p = i.i_pos in 
    match code b.[p] with 
    | 0xCA -> fwd i 5 ; f32 b (p+1)
    | 0xCB -> fwd i 9 ; f64 b (p+1)
    | _ -> fail "Expected float"    

  let list f i = 

    let rec long n acc =       
      if n = 0 then List.rev acc else 
	long (n-1) (f i :: acc)
    in 

    let rec short n = 
      if n = 0 then [] else
	let h = f i in 
	h :: short (n-1)
    in

    let b = i.i_buf and p = i.i_pos in 
    match code b.[p] with 
    | 0xDC -> fwd i 3 ; long (u16 b (p+1)) [] 
    | 0xDD -> fwd i 5 ; long (u32 b (p+1)) []
    | x when x >= 0x90 && x <= 0x9F -> fwd i 1 ; short (x - 0x90)
    | x -> fail (Printf.sprintf "Expected list and found %x" x)
    
  let bool i =     
    match code i.i_buf.[i.i_pos] with 
    | 0xC2 -> fwd i 1 ; false
    | 0xC3 -> fwd i 1 ; true
    | _ -> fail "Expected boolean"

  let extract i len = 
    let p = i.i_pos in
    fwd i len ; 
    String.sub i.i_buf p len

  let string i = 
    let b = i.i_buf and p = i.i_pos in 
    match code b.[p] with 
    | 0xD9 -> fwd i 2 ; extract i (u8 b (p+1))
    | 0xDA -> fwd i 3 ; extract i (u16 b (p+1))
    | 0xDB -> fwd i 5 ; extract i (u32 b (p+1))
    | x when x >= 0xA0 && x <= 0xBF -> fwd i 1 ; extract i (x - 0xA0)
    | _ -> fail "Expected string"

  let apply t fopt x = match fopt with 
    | None -> fail ("Unexpected " ^ t) 
    | Some f -> f x

  let option f i = 
    if code i.i_buf.[i.i_pos] = 0xC0 then None else Some (f i)

  let _int = int
  let _map = map
  let _list = list
  let _string = string
  let _float = float

  let recursive ?string ?int ?float ?bool ?null ?list ?map i = 
    let rec aux i =            
      let c = code i.i_buf.[i.i_pos] in
      if c >= 0xE0 || c <= 0x7F || c >= 0xCC && c <= 0xD3 then
	apply "integer" int (_int i)
      else if c = 0xC0 then
	(match null with None -> fail "Unexpected null" | Some v -> v)
      else if c = 0xC2 || c = 0xC3 then
	apply "boolean" bool (c == 0xC3)
      else if c >= 0x80 && c <= 0x8F || c = 0xDE || c = 0xDF then
	apply "map" map (_map aux aux i)  
      else if c >= 0x90 && c <= 0x9F || c = 0xDD || c = 0xDE then
	apply "list" list (_list aux i)  
      else if c >= 0xA0 && c <= 0xBF || c >= 0xD9 && c <= 0xDB then
	apply "string" string (_string i)
      else if c = 0xCA || c = 0xCB then
	apply "float" float (_float i)
      else	
	fail (Printf.sprintf "Unexpected code %x" c)
    in
    aux i

  let expect_none i = 
    if code i.i_buf.[i.i_pos] <> 0xC0 then fail "Expected null" ;
    fwd i 1 

  let open_array i = 
    let b = i.i_buf and p = i.i_pos in 
    match code b.[p] with 
    | 0xDC -> fwd i 3 ; u16 b (p+1)
    | 0xDD -> fwd i 5 ; u32 b (p+1)
    | x when x >= 0x90 && x <= 0x9F -> fwd i 1 ; x - 0x90
    | x -> fail (Printf.sprintf "Expected list and found %x" x)

  let size_was exp len = 
    if len <> exp then fail ("Incorrect list length, expected " ^ string_of_int exp 
			     ^ " and found " ^ string_of_int len) 

  let expect_array exp i = 
    size_was exp (open_array i)

end

module Raw = struct

  let start_array = Pack.start_array
  let expect_none = Unpack.expect_none
  let expect_array = Unpack.expect_array
  let size_was = Unpack.size_was
  let open_array = Unpack.open_array 
  let bad_variant n = fail ("Unknown variant tag " ^ string_of_int n)
end

type 'a packer = 'a Pack.packer
type 'a unpacker = 'a Unpack.unpacker

let to_string pack x = 
  let buffer = Buffer.create 128 in
  let () = pack x buffer in
  Buffer.contents buffer

let of_string unpack s = 
  let input = { i_buf = s ; i_pos = 0 } in
  unpack input

