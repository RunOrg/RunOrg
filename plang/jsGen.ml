(* © 2013 RunOrg *)

let compile scripts vars = 
  let source = String.concat "" scripts in
  (* TODO: a regexp-based solution would be faster *) 
  List.fold_left 
    (fun source (replace,by) -> 
      let replace = "/*{{ " ^ replace ^ "}}*/" in
      if BatString.exists source replace then
	String.concat by (BatString.nsplit source replace)
      else
	source)
    source vars
