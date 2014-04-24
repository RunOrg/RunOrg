(* © 2014 RunOrg *)

open Std

let notFound id = `NotFound (!! "Form '%s' does not exist." (Form.I.to_string id)) 
let needAdmin id = `Forbidden (!! "You need 'admin' access to on form '%s'." (Form.I.to_string id)) 
let formFilled id = `BadRequest (!! "Form '%s' is already filled." (Form.I.to_string id))

(* Creating a form 
   =============== *)

module Create = Endpoint.Post(struct

  module Arg = type module unit
  module Post = type module <
    ?id : string option ;
    ?label : String.Label.t option ; 
    ?custom : Json.t = Json.Null ; 
     owner : Form.Owner.t ;
     fields : Field.t list ;
     audience : Form.Access.Audience.t ; 
  > 

  module Out = type module <
    id : Form.I.t ;
    at : Cqrs.Clock.t ;
  >

  let path = "forms"

  let alreadyExists id = 
    `Conflict (!! "Identifier %S is already taken." (CustomId.to_string id))

  let needAccess id = 
    `Forbidden (!! "Not allowed to create forms in database %S." (Id.to_string id))

  let response req () post = 
    match Option.bind (post # id) CustomId.validate, post # id with 
    | None, Some id -> return (`BadRequest (!! "%S is not a valid identifier" id))
    | id, _ -> let! result = Form.create (req # as_) ?id ?label:(post # label) 
		 ~owner:(post # owner) ~audience:(post # audience) ~custom:(post # custom) (post # fields) in
	       match result with 
	       | `AlreadyExists id -> return (alreadyExists id)
	       | `NeedAccess id -> return (needAccess id) 
	       | `OK (id,at) -> return (`Accepted (Out.make ~id ~at))

end)

(* Updating a form
   =============== *)

let access cid id = 
  let! form = Form.get id in 
  match form with None -> return `None | Some f -> 
    let! access = Form.Access.compute cid (f # audience) in 
    if Set.mem `Admin access then return `Admin else
      if Set.mem `Fill access then return `Fill else
	return `None

module Update = Endpoint.Put(struct

  module Arg = type module < id : Form.I.t >
  module Put = type module <
    ?label : String.Label.t option ;
    ?custom : Json.t = Json.Null ;
    ?owner : Form.Owner.t option ;
    ?fields : Field.t list option ;
    ?audience : Form.Access.Audience.t option ;    
  >

  module Out = type module <
    at : Cqrs.Clock.t 
  >

  let path = "forms/{id}"

  let response req arg put = 

    (* Special treatment to separate "null" fields from missing fields *)
    let label = match req # body with 
      | Some (`JSON (Json.Object obj)) when List.exists (fun (k,_) -> k = "label") obj -> Some (put # label)
      | _ -> None
    and custom = match req # body with 
      | Some (`JSON (Json.Object obj)) when List.exists (fun (k,_) -> k = "custom") obj -> Some (put # custom)
      | _ -> None
    and owner = put # owner and fields = put # fields and audience = put # audience in 
    
    let! result = Form.update ?label ?custom ?owner ?fields ?audience (req # as_) (arg # id) in
    
    match result with 
    | `OK at -> return (`Accepted (Out.make ~at))
    | `NoSuchForm id -> return (notFound id)
    | `NeedAdmin  id -> return (needAdmin id)
    | `FormFilled id -> return (formFilled id)

end)

(* Reading form data 
   ================= *)

module FormInfo = type module <
  id : Form.I.t ;
  owner : Form.Owner.t ;
  label : String.Label.t option ;
  fields : Field.t list ;
  custom : Json.t ;
  audience : Form.Access.Audience.t option ; 
  access : Form.Access.Set.t ;
>

let make_info cid = 
  let compute = Form.Access.compute cid in
  fun f -> 
    let! access = compute (f # audience) in
    if not (Set.mem `Fill access) then return None else 
      return (Some (FormInfo.make 
		      ~id:(f # id)
		      ~owner:(f # owner)
		      ~label:(f # label)
		      ~fields:(f # fields)
		      ~custom:(f # custom)
		      ~audience:(if Set.mem `Admin access then Some (f # audience) else None)
		      ~access))

module Get = Endpoint.Get(struct

  module Arg = type module < id : Form.I.t >
  module Out = FormInfo

  let path = "forms/{id}"

  let response req arg = 

    let! form = Form.get (arg # id) in
    match form with None -> return (notFound (arg # id)) | Some f -> 
      let! info = make_info (req # as_) f in
      match info with None -> return (notFound (arg # id)) | Some f ->
	return (`OK f) 
    	
end)

module ShortInfo = type module <
  id : Form.I.t ;
  owner : Form.Owner.t ;
  label : String.Label.t option ;
  fields : int ;
  access : Form.Access.Set.t ;
>

let make_short cid = 
  let compute = Form.Access.compute cid in
  fun f -> 
    let! access = compute (f # audience) in
    if not (Set.mem `Fill access) then return None else 
      return (Some (ShortInfo.make 
		      ~id:(f # id)
		      ~owner:(f # owner)
		      ~label:(f # label)
		      ~fields:(List.length (f # fields))		    
		      ~access))

module ListAll = Endpoint.Get(struct

  module Arg = type module unit
  module Out = type module <
    list  : ShortInfo.t list ; 
  >

  let path = "forms"

  let response req args = 
    let limit = Option.default 1000 (req # limit) in
    let offset = Option.default 0 (req # offset) in
    let! forms = Form.list (req # as_) ~limit ~offset in
    let! list = List.M.filter_map (make_short (req # as_)) forms in 
    return (`OK (Out.make ~list))

end)

(* Filling forms
   ============= *)

module Fill = Endpoint.Put(struct

  module Arg = type module < id : Form.I.t ; fid : PId.t >
  module Put = type module <
    data : Json.t ;
  >

  module Out = type module <
    at : Cqrs.Clock.t ;
  >

  let path = "forms/{id}/filled/{fid}"

  let noSuchField id fid =
    `BadRequest (!! "Field %S does not exist in form %S." 
		    (Field.I.to_string fid) (Form.I.to_string id))

  let missingRequiredField id fid =
    `BadRequest (!! "Field %S is required in form %S but no data was provided." 
		    (Field.I.to_string fid) (Form.I.to_string id))

  let invalidFieldFormat id fid k =
    `BadRequest (!! "Field %S in form %S is of kind %S, incompatible with provided data." 
		    (Field.I.to_string fid) (Form.I.to_string id) (Field.string_of_kind k))

  let noSuchOwner id fid =
    `NotFound (!! "%s does not exist." 
		  (match fid with 
		  | `Person cid -> !! "Person %S" (PId.to_string cid)))

  let needAdmin id fid =
    `Forbidden (!! "You need admin access to fill form %S for %s." 
		   (Form.I.to_string id)
		   (match fid with 
		   | `Person cid -> !! "person %S" (PId.to_string cid)))
      
  let response req args put = 
    
    let fid  = `Person (args # fid) in
    let id   = args # id in

    let data = match put # data with 
      | Json.Object l -> Map.of_list (List.map (fun (k,v) -> Field.I.of_string k, v) l)
      | _ -> Map.empty in

    let! result = Form.fill (req # as_) id fid data in

    match result with
    | `OK                         at -> return (`Accepted (Out.make ~at))
    | `NoSuchForm                 id -> return (notFound id)
    | `NoSuchField          (id,fid) -> return (noSuchField id fid) 
    | `MissingRequiredField (id,fid) -> return (missingRequiredField id fid)
    | `InvalidFieldFormat (id,fid,k) -> return (invalidFieldFormat id fid k)
    | `NoSuchOwner          (id,fid) -> return (noSuchOwner id fid)
    | `NeedAdmin            (id,fid) -> return (needAdmin id fid) 

end)

module GetFilled = Endpoint.Get(struct

  module Arg = type module < id : Form.I.t ; fid : PId.t >
  module Out = type module <
    owner : PId.t ;
    data  : Json.t ;
  >

  let path = "forms/{id}/filled/{fid}"

  let notFilled id fid =
    `NotFound (!! "Form %S is not filled for %s." 
		  (Form.I.to_string id)
		  (match fid with 
		  | `Person cid -> !! "person %S" (PId.to_string cid)))
      
  let needAdmin id fid =
    `Forbidden (!! "You need admin access to fill form %S for %s." 
		   (Form.I.to_string id)
		   (match fid with 
		   | `Person cid -> !! "person %S" (PId.to_string cid)))

  let response req args = 

    let owner = args # fid in
    let fid   = `Person (args # fid) in
    let id    = args # id in
    
    let! result = Form.get_filled (req # as_) id fid in
    
    let  output data = 
      Json.Object (List.map (fun (k,v) -> Field.I.to_string k, v) (Map.to_list data)) in

    match result with 
    | `OK            data -> return (`OK (Out.make ~owner ~data:(output data)))
    | `NoSuchForm      id -> return (notFound id)
    | `NotFilled (id,fid) -> return (notFilled id fid)
    | `NeedAdmin (id,fid) -> return (needAdmin id fid) 

end)

module ListFilled = Endpoint.Get(struct

  module Arg = type module < id : Form.I.t >
  module Item = type module <        
    owner : PId.t ;
    data  : Json.t ;
  >

  module Out = type module <
    list  : Item.t list ;
    count : int ;
  >

  let path = "forms/{id}/filled"

  let needAdmin id =
    `Forbidden (!! "You need admin access to list filled instances of form %S." 
		   (Form.I.to_string id))

  let response req args = 

    let id     = args # id in
    let limit  = Option.default 100 (req # limit) in
    let offset = Option.default 0 (req # offset) in
    
    let! result = Form.list_filled (req # as_) ~limit ~offset id in
    
    let  output o = 
      Out.make ~count:(o # count) ~list:(List.map (fun i -> Item.make
	~owner:(match i # owner with `Person cid -> cid)
	~data:(Json.Object (List.map (fun (k,v) -> Field.I.to_string k, v) (Map.to_list (i # data))))
      ) (o # list)) 
    in

    match result with 
    | `OK       data -> return (`OK (output data))
    | `NoSuchForm id -> return (notFound id)
    | `NeedAdmin  id -> return (needAdmin id)

end)

(* Form statistics 
   =============== *)

module Stats = Endpoint.Get(struct

  module Arg = type module < id : Form.I.t >
  module Out = type module <
    count : int ;
    fields : Form.Stats.Summary.t ;
  >

  let path = "forms/{id}/stats"

  let needAdmin id =
    `Forbidden (!! "You need admin access to view statistics of form %S." 
		   (Form.I.to_string id))

  let response req arg = 

    let! stats = Form.stats (req # as_) (arg # id) in
    match stats with 
    | `NoSuchForm id -> return (notFound id)
    | `NeedAdmin  id -> return (needAdmin id) 
    | `OK       data -> return (`OK (data :> Out.t)) 
    	
end)
