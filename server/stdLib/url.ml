(* © 2014 RunOrg *)

(* Url decoding and encoding
   ========================= *)

let reservedRE = Str.regexp "[^-._~a-zA-Z0-9]"

let urlencode str = 
  Str.global_substitute reservedRE 
    (fun s -> match s.[0] with (* <-- reserved matches characters *)
      | ' ' -> "+"
      |  c  -> Printf.sprintf "%%%02x" (Char.code c))
    str

let encodedRE = Str.regexp "%[0-9a-fA-F][0-9a-fA-F]"

let urldecode str = 
  Str.global_substitute encodedRE
    (fun s -> Scanf.sscanf str "%%%x" (fun i -> String.make 1 (Char.chr i)))
    str

(* Internal storage format 
   ======================= *)

include Fmt.Make(struct

  include type module [ `Raw of string ]

  let t_of_json = function 
    | Json.String s -> `Raw s
    | json -> Json.parse_error "url" json

  let json_of_t = function 
    | `Raw s -> Json.String s

end)

let to_string = function 
  | `Raw s -> s 
  
let of_string url = 
  Some (`Raw url)

let of_string_template id url = 
  Some (fun i -> let segs = BatString.nsplit url ("{"^id^"}") in
		 `Raw (String.concat i segs))

(* URL manipulation 
   ================ *)

let raw_add_query_string_parameter key value t = 

  let add key value t = 
    let sep = if BatString.exists t "?" then "&" else "?" in 
    t ^ sep ^ key ^ "=" ^ value (* TODO: escaping *)
  in

  try let url, hash = BatString.split t "#" in
      add key value url ^ "#" ^ hash
  with Not_found -> add key value t

let add_query_string_parameter key value = function 
  | `Raw t -> `Raw (raw_add_query_string_parameter key value t)

(* Test URL equality 
   ================= *)

let equal url1 url2 = 

  (* TODO: perform canonicalization *)
  url1 = url2
