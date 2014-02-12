(* © 2013 RunOrg *)

open Std

let forbidden = `Unauthorized "Token is not a server administrator"
let bad_auth  = `Forbidden "Could not log in as server administrator"

(* Administration UI 
   ================= *)

let () = 
  Endpoint.static "admin" "text/html" "sites/admin/.static/index.html" ;
  Endpoint.static "admin/script.js" "text/javascript" "sites/admin/.assets/all.js" ;
  Endpoint.static "admin/en.js" "text/javascript" "sites/admin/.assets/en.js" ;
  Endpoint.static "admin/style.css" "text/css" "sites/admin/.assets/all.css" ;
  Endpoint.static "admin/logo.png" "image/png" "sites/admin/.static/logo-runorg-50x50.png"

(* Authenticate as a server administrator 
   ====================================== *)

module Auth_Persona = Endpoint.SPost(struct

  module Arg  = type module unit
  module Post = type module < assertion : string >
  module Out  = type module < token : Token.I.t ; email : string >

  let path = "admin/auth/persona"

  let response req () p = 
    let! result = ServerAdmin.auth_persona (p # assertion) in
    match result with None -> return bad_auth | Some (token, email) ->
      let token = Token.I.decay token in 
      return (`OK (Out.make ~token ~email)) 

end)

(* List of all registered administrators 
   ===================================== *)

module All = Endpoint.SGet(struct

  module Admin = type module < email : string ; fromConfig : bool >

  module Arg = type module unit
  module Out = type module < admins : Admin.t list >

  let path = "admin/all" 

  let response req () = 
    let! token = Option.M.bind Token.is_server_admin (req # token) in
    match token with None -> return forbidden | Some token -> 
      let! admins = ServerAdmin.all token in 
      return (`OK (Out.make ~admins))

end)

(* Create a new database 
   ===================== *)

module Db_Create = Endpoint.SPost(struct

  module Arg  = type module unit
  module Post = type module < label : string >
  module Out  = type module < id : Id.t ; at : Cqrs.Clock.t >

  let path = "db/create"

  let response req () p = 
    let! token = Option.M.bind Token.is_server_admin (req # token) in
    match token with None -> return forbidden | Some token -> 
      let! id, at = Db.create token (p # label) in
      return (`Accepted (Out.make ~id ~at))

end)

(* List all available databases 
   ============================ *)

module Db_All = Endpoint.SGet(struct

  module Arg = type module < 
   ?limit : int = 100 ; 
   ?offset : int = 0
  >

  module Item = type module < id : Id.t ; label : string ; created : Time.t >
  module Out  = type module < count : int ; list : Item.t list >

  let path = "db/all"

  let response req p = 
    let! token = Option.M.bind Token.is_server_admin (req # token) in 
    match token with None -> return forbidden | Some token ->      
      let! list  = Db.all ~limit:(p # limit) ~offset:(p # offset) token in 
      let! count = Db.count token in   
      return (`OK (Out.make ~count ~list))

end)

(* Nominate an administrator for a database
   ======================================== *)

module Db_Admin_Nominate = Endpoint.Post(struct

  module Arg = type module unit
  module Post = type module (String.Label.t list) 
  module Out = type module < at : Cqrs.Clock.t >

  let admin = Group.I.of_string "admin" 
  let path = "groups/admin/nominate"

  let response req args post = 
    let! token = Option.M.bind Token.is_server_admin (req # token) in 
    match token with None -> return forbidden | Some _ ->      

      (* Create contacts by e-mail *)
      let! created = List.M.map (fun email -> Contact.create email) post in 
      let  cids = List.map fst created in 

      (* Add contacts to group *)
      let! at = Group.add cids [ admin ] in 
      
      (* Merge clocks *)
      let  at = List.fold_left (fun acc (_,clock) -> Cqrs.Clock.merge acc clock) at created in
      return (`Accepted (Out.make ~at))

end)
