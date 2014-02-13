(* © 2014 RunOrg *)

(* Administration UI 
   ================= *)

let () = 
  Endpoint.static "admin" "text/html" "sites/admin/.static/index.html" ;
  Endpoint.static "admin/script.js" "text/javascript" "sites/admin/.assets/all.js" ;
  Endpoint.static "admin/en.js" "text/javascript" "sites/admin/.assets/en.js" ;
  Endpoint.static "admin/style.css" "text/css" "sites/admin/.assets/all.css" ;
  Endpoint.static "admin/logo.png" "image/png" "sites/admin/.static/logo-runorg-50x50.png"

(* Testing (or documentation) UI
   ============================= *)

let () = 

  (* Static entry point. *)
  Endpoint.static "docs" "text/html" "sites/docs/.static/index.html" ;

  (* Static assets generated though the JS app compiler. *)
  Endpoint.static "docs/script.js" "text/javascript" "sites/docs/.assets/all.js" ;
  Endpoint.static "docs/style.css" "text/css" "sites/docs/.assets/all.css" ;

  (* Directory of all tests, from the test module. *)
  Endpoint.json "docs/all.json" Json.(of_assoc Test.all) ;
  List.iter (fun (path,_) -> Endpoint.static ("docs/" ^ path) "text/plain" ("test/" ^ path)) Test.all 

(* Database UI 
   =========== *)

let () = 
  Endpoint.static "db/{-}/ui" "text/html" "sites/default/.static/index.html" ;
  Endpoint.static "db/{-}/script.js" "text/javascript" "sites/default/.assets/all.js" ;
  Endpoint.static "db/{-}/en.js" "text/javascript" "sites/default/.assets/en.js" ;
  Endpoint.static "db/{-}/style.css" "text/css" "sites/default/.assets/all.css" 
