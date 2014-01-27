(* © 2014 RunOrg *)

open Std 

(* Testing (or documentation) UI
   ============================= *)

let () = 
  if Configuration.test then begin

    (* Static entry point. *)
    Endpoint.static "docs" "text/html" "static/testUI/index.html" ;

    (* Static assets generated though the JS app compiler. *)
    Endpoint.static "docs/script.js" "text/javascript" "_assets/testUI/all.js" ;
    Endpoint.static "docs/style.css" "text/css" "_assets/testUI/all.css" ;

    (* Directory of all tests, from the test module. *)
    Endpoint.json "docs/all.json" Json.(of_assoc Test.all) ;
    List.iter (fun (path,_) -> Endpoint.static ("docs/" ^ path) "text/plain" ("test/" ^ path)) Test.all ;

  end 

