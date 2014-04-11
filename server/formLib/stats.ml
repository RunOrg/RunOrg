(* © 2014 RunOrg *)

open Std

(* Stat storage objects 
   ==================== *)

module SText = type module <
  missing : int ;
  filled  : int ;
>

module STime = type module <
  missing : int ;
  filled  : int ;
  first   : Time.t option ;
  last    : Time.t option ;
>

module SJson = type module <
  missing   : int ;
  filled    : int ;
>

module SSingle = type module <
  missing : int ;
  filled  : int ;
  items   : int array ;
>

module SMulti = type module <
  missing : int ;
  filled  : int ;
  items   : int array ;
>

module SContact = type module <
  missing : int ;
  filled : int ;
  contacts : int ;
  top10 : (CId.t * int) list ;
>

(* JSON output does not include variant information : just an object
   with properties appropriate for the field. *)
module FieldStat = Fmt.Make(struct

  include type module 
      [ `Text of SText.t 
      | `Time of STime.t
      | `Json of SJson.t 
      | `Single of SSingle.t 
      | `Multi of SMulti.t 
      | `Contact of SContact.t ]

  let t_of_json json = 
    failwith "JSON unserialization not supported"

  let json_of_t = function
    | `Text t -> SText.to_json t
    | `Time t -> STime.to_json t
    | `Json t -> SJson.to_json t
    | `Single t -> SSingle.to_json t
    | `Multi t -> SMulti.to_json t
    | `Contact t -> SContact.to_json t
    
end)

(* JSON output is a { <field> : <stat> } dictionary. *)
module Summary = Fmt.Map(struct

  module Inner = Fmt.Make(struct
    
    include type module (( Field.I.t * FieldStat.t ) list)
	
    let t_of_json json =
      failwith "JSON unserialization not supported"
	
    let json_of_t t = 
      Json.Object (List.map (fun (k,v) -> Field.I.to_string k, FieldStat.to_json v) t)

  end)

  type t = (Field.I.t, FieldStat.t) Map.t

  let from_inner t = Map.of_list t 

  let to_inner t = Map.to_list t 

end)

(* Computing statistics based on data 
   ================================== *)

class type aggregator = object
  method add : Json.t -> unit
  method compile : FieldStat.t 
end

class text = object (self)

  val mutable missing = 0
  val mutable filled  = 0

  method add = function 
    | Json.Null -> missing <- missing + 1
    | Json.String s -> filled <- filled + 1 ;		       
    | _ -> ()

  method missing = missing 
  method filled  = filled

  method compile = ( `Text (self :> SText.t) : FieldStat.t )

end 

class time = object (self)

  val mutable missing = 0
  val mutable filled  = 0
  val mutable first   = None
  val mutable last    = None

  method add json = 
    match Time.of_json_safe json with 
    | None -> missing <- missing + 1
    | Some t -> ( filled <- filled + 1 ;
		  first  <- ( match first with Some f when f < t -> first | _ -> Some t) ;
		  last   <- ( match last  with Some f when f > t -> last  | _ -> Some t) )

  method missing = missing
  method filled  = filled
  method first   = first
  method last    = last

  method compile = ( `Time (self :> STime.t) : FieldStat.t )

end

class json = object (self)

  val mutable missing = 0
  val mutable filled  = 0

  method add json = 
    if json = Json.Null then
      missing <- missing + 1 
    else 
      filled <- filled + 1

  method missing = missing
  method filled  = filled

  method compile = ( `Json (self :> SJson.t) : FieldStat.t )

end 

class single n = object (self)

  val max = n
  val mutable missing = 0
  val mutable filled  = 0
  val items = Array.make n 0 

  method add = function 
  | Json.Null -> missing <- missing + 1
  | Json.Int i when i >= 0 && i < max -> filled <- filled + 1 ; items.(i) <- items.(i) + 1 
  | _ -> () 

  method missing = missing
  method filled  = filled
  method items   = items
    
  method compile = ( `Single (self :> SSingle.t) : FieldStat.t )

end

class multi n = object (self)

  val max = n
  val mutable missing = 0
  val mutable filled  = 0
  val items = Array.make n 0 

  method add = function 
  | Json.Null 
  | Json.Array [] -> missing <- missing + 1
  | Json.Array l  -> let is = List.filter_map (function Json.Int i -> Some i | _ -> None) l in
		     let is = List.filter (fun i -> i >= 0 && i < max) is in 
		     let is = List.sort_unique compare is in
		     List.iter (fun i -> items.(i) <- items.(i) + 1) is ;
		     filled <- filled + 1 ;
  | _ -> () 

  method missing = missing
  method filled  = filled
  method items   = items
    
  method compile = ( `Multi (self :> SMulti.t) : FieldStat.t )

end

class contact = object (self)

  val mutable missing = 0
  val mutable filled  = 0
  val mutable counts  = Map.empty
    
  method add json = 
    match CId.of_json_safe json with None -> missing <- missing + 1 | Some cid -> 
      filled <- filled + 1 ;
      let n = try Map.find cid counts with Not_found -> 0 in
      counts <- Map.add cid (1 + n) counts 

  method missing  = missing
  method filled   = filled
  method contacts = Map.cardinal counts
  method top10    = counts
    |> Map.to_list
    |> List.sort (fun (_,a) (_,b) -> compare b a)
    |> List.take 10 

  method compile = ( `Contact (self :> SContact.t) : FieldStat.t )

end

let aggregator_of_kind = function 
  | `Text 
  | `RichText -> (new text :> aggregator)
  | `DateTime -> (new time :> aggregator)
  | `SingleChoice l -> (new single (List.length l) :> aggregator)
  | `MultipleChoice l -> (new multi (List.length l) :> aggregator)
  | `Json -> (new json :> aggregator) 
  | `Contact -> (new contact :> aggregator) 

let aggregators fields = 
  fields
  |> List.map (fun f -> f # id, aggregator_of_kind (f # kind))
  |> Map.of_list 

(* Traversing all instances of a form
   ================================== *)

let traverse fid aggregators = 

  (* Build a finite async sequence *)

  let per_batch = 5000 (* Cells per batch *) in
  let limit = max 10 (per_batch / Map.cardinal aggregators) in

  let cursor offset =
    let  offset = Option.default 0 offset in 
    let! list   = Cqrs.FeedMapView.list View.fillInfo ~limit ~offset fid in
    let  n      = List.length list in 
    let  offset = if n = limit then Some (offset + n) else None in
    let  list   = List.map (fun (_,_,instance) -> instance) list in
    return (list, offset)
  in

  let seq = Seq.of_finite_cursor cursor None in 

  (* Process the sequence *)

  let process_instance instance =
    let data = instance # data in 
    Map.iter (fun fid agg -> agg # add (try Map.find fid data with Not_found -> Json.Null)) aggregators
  in

  let! () = Seq.iter ~parallel:true process_instance seq in

  return (Map.map (#compile) aggregators) 

let process fid =
  let! form = Cqrs.MapView.get View.info fid in
  match form with None -> return Map.empty | Some form -> 
    traverse fid (aggregators (form # fields))

(* Cache implementation 
   ==================== *)

let compute = 
  Cqrs.HardStuffCache.make "form.stats" 0 
    (module I : Fmt.FMT with type t = I.t) 
    (module Summary : Fmt.FMT with type t = Summary.t) 
    process 

