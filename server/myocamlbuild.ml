open Ocamlbuild_plugin

let path_to_pp = "../../syntax/syntax.cmo"

let _ = dispatch begin function
  | After_rules ->
    flag ["ocamldep"; "custom-pp"] (S[A"-ppopt";A path_to_pp]);
    flag ["compile"; "custom-pp"] (S[A"-ppopt";A path_to_pp]);
    flag ["compile"] (S[A"-g"]) ;
    flag ["link"] (S[A"-g"]) ;
  | _ -> ()
end

