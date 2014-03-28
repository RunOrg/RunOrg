(* © 2014 RunOrg *)

open Std

include Fmt.Make(struct

  type t = (Field.I.t, Json.t) Map.t

  let json_of_t m = 
    Json.Object 
      (List.filter (fun (_,data) -> data <> Json.Null)
	 (Map.foldi (fun fid json list -> (Field.I.to_string fid, json) :: list) m []))

  let t_of_json = function 
    | Json.Object l -> 
      List.fold_left (fun map (fid,json) ->
	match Field.I.of_string_checked fid with 
	| None -> raise Json.Error ([], !! "Not a field identifier: %S" fid)
	| Some fid -> Map.add fid json map) Map.empty l
    | json -> Json.parse_error "Expected field data dictionary." json

  let pack m = 
    Json.pack (json_of_t m)

  let unpack u = 
    t_of_json (Json.unpack u)

end)
