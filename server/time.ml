(* Ohm is © 2013 Victor Nicollet *)

open BatPervasives

module Tz = struct
  type t = float 
  let gmt = 0.
end

type time = { h : int ; i : int ; s : int }
type date = { y : int ; m : int ; d : int ; t : time option }

let of_compact s = 
  try
    let y = int_of_string (String.sub s 0 4) in
    let m = int_of_string (String.sub s 4 2) in
    let d = int_of_string (String.sub s 6 2) in
    if String.length s = 8 then
      Some { y ; m ; d ; t = None }
    else
      let h = int_of_string (String.sub s 8 2) in
      let i = int_of_string (String.sub s 10 2) in
      let s = int_of_string (String.sub s 12 2) in
      Some { y ; m ; d ; t = Some { h ; i ; s }}
  with _ -> None

let of_iso8601 s = 
  try 
    if String.length s = 8 || String.length s = 14 then
      of_compact s 
    else if String.length s = 20 then
      Scanf.sscanf s "%d-%d-%dT%d:%d:%dZ" 
	(fun y m d h i s -> Some { y ; m ; d ; t = Some { h ; i ; s }})
    else
      Scanf.sscanf s "%d-%d-%d" 
	(fun y m d -> Some { y ; m ; d ; t = None }) 
  with _ -> None

let u4 i = if i < 0 then 0 else if i >= 10000 then 9999 else i 
let u2 i = if i < 0 then 0 else if i >= 100 then 99 else i

let to_iso8601 d = 
  match d.t with 
    | None -> Printf.sprintf "%04d-%02d-%02d" (u4 d.y) (u2 d.m) (u2 d.d)
    | Some t -> Printf.sprintf "%04d-%02d-%02dT%02d:%02d:%02dZ" 
      (u4 d.y) (u2 d.m) (u2 d.d) (u2 t.h) (u2 t.i) (u2 t.s) 

let to_compact d = 
  match d.t with 
    | None -> Printf.sprintf "%04d%02d%02d" (u4 d.y) (u2 d.m) (u2 d.d)
    | Some t -> Printf.sprintf "%04d%02d%02d%02d%02d%02d"  
      (u4 d.y) (u2 d.m) (u2 d.d) (u2 t.h) (u2 t.i) (u2 t.s) 

include Fmt.Make(struct
  type t = date
  let t_of_json = function 
    | Json.String s -> begin 
      match of_iso8601 s with 
	| Some d -> d
	| None -> raise (Json.Error (Printf.sprintf "Unexpected date format : %S" s))
    end
    | _ -> raise (Json.Error "Expected string representation for date") 
  let json_of_t d = Json.String (to_iso8601 d) 
  let pack d = 
    Json.pack (Json.Array (List.map (fun i -> Json.Int i) (match d.t with 
    | None   -> [ d.y ; d.m ; d.d ]
    | Some t -> [ d.y ; d.m ; d.d ; t.h ; t.i ; t.s ])))
  let unpack bytes = 
    let open Json in 
    match unpack bytes with 
    | Array [ Int y ; Int m ; Int d ] -> { y ; m ; d ; t = None }
    | Array [ Int y ; Int m ; Int d ; Int h ; Int i ; Int s ] -> { y ; m ; d ; t = Some { h ; i ; s } }
    | _ -> raise (Pack.Error "Expected 3-int or 6-int")
end)

let of_timestamp ts = 
  let tm = Unix.gmtime ts in
  { y = 1900 + tm.Unix.tm_year ; 
    m = 1 + tm.Unix.tm_mon ;
    d = tm.Unix.tm_mday ;
    t = Some {
      h = tm.Unix.tm_hour ;
      i = tm.Unix.tm_min ;
      s = tm.Unix.tm_sec 
    }
  }

let now () = of_timestamp (Unix.gettimeofday ()) 

(* Small piece of date magic. This will break during the
   specific hour or so when DST changes, but it's the best
   we can do without timezone support in OCaml. *)

let mkgmtime tm = 
  let ts_local, _ = Unix.mktime tm in
  let ts_iter,  _ = Unix.mktime (Unix.gmtime ts_local) in
  2. *. ts_local -. ts_iter

let to_timestamp t = 

  let tm_hour, tm_min, tm_sec = match t.t with 
    | None -> 0, 0, 0 
    | Some t -> t.h, t.i, t.s
  in

  let tm = Unix.({ 
    tm_year = t.y - 1900 ; 
    tm_mon = t.m - 1 ;
    tm_mday = t.d ;
    tm_hour ;
    tm_min ;
    tm_sec ;
    (* 3 fields below ignored by mktime *)
    tm_wday = 0 ;
    tm_yday = 0 ;
    tm_isdst = false
  }) in

  mkgmtime tm 

let datetime tz year month day hour minute second = 

  let tm = Unix.({ 
    tm_year = year - 1900 ; 
    tm_mon = month - 1 ;
    tm_mday = day ;
    tm_hour = hour ; 
    tm_min = minute ;
    tm_sec = second ;
    (* 3 fields below ignored by mktime *)
    tm_wday = 0 ;
    tm_yday = 0 ;
    tm_isdst = false
  }) in

  of_timestamp (mkgmtime tm +. tz)

let date y m d = 
  { y ; m ; d ; t = None }

let day_only d = { d with t = None }

let ymd d = d.y, d.m, d.d

let hms d = match d.t with None -> None | Some t -> Some (t.h, t.i, t.s)

let min = { y =    0 ; m =  1 ; d =  1 ; t = None }
let max = { y = 9999 ; m = 12 ; d = 31 ; t = None }
