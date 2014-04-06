(* © 2014 RunOrg *)

open Std

module I = struct
  include Id.Phantom
end

module Hash = type module 
    [ `SHA1 "SHA-1" 
    ]

(* Events and event stream 
   ======================= *)

module Events = type module 
    [ `Created of < 
      id   : I.t ; 
      cid  : CId.t option ; 
      ip   : IpAddress.t ; 
      hash : Hash.t ; 
      key  : string >
    ]

module Store = Cqrs.Stream(struct
  include Events
  let name = "key"
end)

(* Views and projections 
   ===================== *)

let projection = Cqrs.Projection.make "key" O.cqrs

module Value = type module < 
  hash : Hash.t ; 
  key : string ; 
  ip : IpAddress.t ;
  cid : CId.t option ; 
  time : Time.t ;
  enabled : bool 
>

let value = 
  
  let valueV, value = Cqrs.MapView.make projection "value" 1
    (module I : Fmt.FMT with type t = I.t)
    (module Value : Fmt.FMT with type t = Value.t) in

  let () = Store.track valueV begin function 

    | `Created ev -> 

      let! ctx = Run.context in      
      Cqrs.MapView.update value (ev # id)
	(function 
	| None   -> `Put (Value.make ~hash:(ev # hash) ~key:(ev # key) ~ip:(ev # ip)
			    ~time:(ctx # time) ~cid:(ev # cid) ~enabled:true)
	| Some _ -> `Keep)

  end in
  
  value

(* Commands 
   ======== *)

(* Who is allowed to create new forms ? *)
let create_audience = Audience.admin 

let create cid ip hash key = 
  
  let! allowed = Audience.is_member cid create_audience in 
  
  if not allowed then 
    let! ctx = Run.context in 
    return (`NeedAccess (ctx # db))
  else

    let  id = I.gen () in
    let! clock = Store.append [ Events.created ~id ~cid ~hash ~key ~ip ] in
    return (`OK (id, clock))
 
(* Queries 
   ======= *)
    
let hmac id assertion = 
  let! info = Cqrs.MapView.get value id in
  match info with None -> return None | Some info -> 
    if not (info # enabled) then return None else 
      return (Some begin match info # hash with 
	
      | `SHA1 -> ( Sha1.hmac (info # key) assertion,
		   `SHA1, 
		   lazy (Sha1.hmac "" assertion) )
	
      end)

type info = <
  id : I.t ;
  hash : Hash.t ;
  ip : IpAddress.t ;
  time : Time.t ;
  enabled : bool ;
>

let format_info id value = object
  method id      = id
  method hash    = value # hash 
  method ip      = value # ip
  method time    = value # time
  method enabled = value # enabled 
end

let list ~limit ~offset = 
  let! list = Cqrs.MapView.all ~limit ~offset value in
  let! count = Cqrs.MapView.count value in 
  return (List.map (fun (id, value) -> format_info id value) list, count) 
