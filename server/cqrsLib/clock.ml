type stream = int

module Map = BatMap

include Fmt.Make(struct  

  type t = (stream, int) Map.t

  let json_of_t map = 
    let open Json in 
    Object (Map.foldi (fun k v l -> ( string_of_int k, Int v ) :: l) map [])

  let t_of_json json = 
    let open Json in 
    let list = to_assoc json in
    List.fold_left (fun m (k,v) -> Map.add (int_of_string k) (to_int v) m) Map.empty list 

  let pack m p = 
    let open Pack.Pack in 
    map int int (Map.foldi (fun k v l -> (k,v) :: l) m []) p 

  let unpack p = 
    let open Pack.Unpack in 
    let list = map int int p in
    List.fold_left (fun m (k,v) -> Map.add k v m) Map.empty list 

end)
    
let empty = Map.empty

let is_empty t = t = empty

let at s i = Map.add s i empty

let merge ma mb = 
  let add_if_greater k v m = 
    if (try Map.find k m < v with Not_found -> true) then
      Map.add k v m else m in
  Map.foldi add_if_greater ma mb

let earlier_than_constraint ma mb = 
  Map.for_all (fun k v -> try Map.find k mb >= v with Not_found -> true) ma

let earlier_than_checkpoint ma mb = 
  Map.for_all (fun k v -> try Map.find k mb >= v with Not_found -> false) ma

let get m s = 
  try Some (Map.find s m) with Not_found -> None 
