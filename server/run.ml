(* © 2013 RunOrg *)

(* Types, both public and private 
   ============================== *)

type thr             = Do of thr list Lazy.t
type ('ctx,'value) t = 'ctx -> ('value -> thr) -> thr

type ('ctx,'value) value  = ('ctx,'value) t
type 'ctx          effect = ('ctx,unit) t
type 'ctx          thread = ('ctx,unit) t

(* Monad usage 
   =========== *)

let return x = fun _ emit -> Do (lazy [emit x])   
let bind f m = fun c emit -> m c (fun x -> f x c emit)
let map  f m = fun c emit -> m c (fun x -> emit (f x))
let unwrap m = fun c emit -> m c (fun x -> x c emit) 

(* Internal usage only *)
let (|>>) m f = map f m 

(* Context manipulation 
   ==================== *)

let context = fun c emit -> Do (lazy [emit c]) 

let with_context c m = fun _ emit -> m c emit

let edit_context f m = fun c emit -> m (f c) emit

(* Concurrency manipulation 
   ======================== *)

let nop = Do (lazy [])

let yield m = fun c emit -> Do (lazy [nop ; m c emit]) 

let join  a b f = fun c emit -> let ra = ref None and rb = ref None in 
				let emit_a xa = match !rb with 
				  | None    -> ra := Some xa ; nop
				  | Some xb -> f xa xb c emit
				and emit_b xb = match !ra with
				  | None    -> rb := Some xb ; nop
				  | Some xa -> f xa xb c emit
				in
				Do (lazy [a c emit_a ; b c emit_b]) 

let fork a b = fun c emit -> Do (lazy [b c emit ; a c (fun _ -> nop)])

class ['ctx] joiner = object (self) 

  val mutable count    = 0
  val mutable my_emit  = ( None : (unit -> thr) option )

  method wait : ('ctx,unit) t = fun _ emit -> 
    if count = 0 then emit () else 
      ( my_emit <- Some emit ; nop )

  method start (m : ('ctx, unit) t) = 
    count <- count + 1 ;
    let emit_if_zero () = 
      count <- count - 1 ;
      if count = 0 then match my_emit with 
        | None -> nop
        | Some emit -> ( my_emit <- None ; emit () )
      else nop
    in
    fun c emit -> Do (lazy [ emit () ; m c emit_if_zero ]) 
      
end

class mutex = object (self)

  val waiting = Queue.create ()
  val mutable locked = false

  method lock : 'ctx 'a . ('ctx, 'a) t -> ('ctx, 'a) t = fun m c emit -> 

    let emit r = 
      if Queue.is_empty waiting then begin
	locked <- false ;
	emit r 
      end else begin
	let next = Queue.take waiting in
	Do (lazy [ next () ; emit r ])
      end
    in
      
    if locked then begin 
      Queue.add (fun () -> m c emit) waiting ; nop
    end else begin 
      locked <- true ; m c emit
    end

  method if_unlocked : 'ctx 'a . ('ctx, 'a) t -> ('ctx, 'a) t = fun m ->
    if locked then self # lock m else m 
    
end 

(* Utilities 
   ========= *)

let memo m = 
  let r = ref None in 
  fun c emit -> Do (lazy [(
    match !r with 
      | Some (c',v) when c' == c -> emit v 
      | _ -> m c (fun x -> r := Some (c,x) ; emit x) 
  )])

let of_lazy l = fun c emit -> Do (lazy [emit (Lazy.force l)])
let of_func f = fun c emit -> Do (lazy [emit (f ())])

let of_call f a = fun c emit -> f a c emit

(* List functions 
   ============== *)

module ForList = struct

  let map f l = fun c emit -> 
    if l = [] then emit [] else 
      let num_unevaled = ref (List.length l) in
      let result = List.map (fun x -> x, ref None) l in
      let emit r y = 
	if !r = None then decr num_unevaled ; 
	r := Some y ;
	if !num_unevaled > 0 then nop 
	else emit (List.map 
		     (fun (x,r) -> match !r with Some y -> y | None -> assert false) 
		     result)
      in
      Do (lazy (List.map (fun (x,r) -> f x c (emit r)) result))
	
  let filter_map f l = map f l |>> BatList.filter_map BatPervasives.identity
  let collect f l = map f l |>> List.concat 

  let rec find f = function 
    | []     -> return None
    | h :: t -> bind (function 
      | None -> find f t
      | some -> return some) (f h) 
      
  let rec fold_left f a = function
    | []     -> return a
    | h :: t -> bind (fun a -> fold_left f a t) (f a h) 

  let mfold f a l = bind (fold_left (fun a f -> f a) a) (map f l) 
		       
  let iter f l = fun c emit -> 
    if l = [] then emit () else 
      let r = ref (List.length l) in
      let emit () = 
	decr r ; 
	if !r = 0 then emit () else nop 
      in
      Do (lazy (List.map (fun x -> f x c emit) l))
	
  let exists pred l = 
    find (fun x -> pred x |>> (fun px -> if px then Some () else None)) l
    |>> BatOption.is_some

end

module ForOption = struct

  let map f = function 
    | None   -> (fun c emit -> emit None)
    | Some x -> (fun c emit -> f x c (fun y -> emit (Some y)))
      
  let bind f = function
    | None   -> (fun c emit -> emit None)
    | Some x -> (fun c emit -> f x c emit)

end

let loop f = 
  let rec loop () = f (yield (of_call loop ())) in loop () 

let sleep t = 
  let ends = Unix.gettimeofday () +. t in
  loop (fun continue -> if Unix.gettimeofday () < ends then continue else return ())

(* Evaluation ------------------------------------------------------------------------------ *)

exception Timeout 

let eval ?timeout ctx m = 
  let queue  = Queue.create () in 
  let r      = ref None in 
  let emit x = r := Some x ; nop in 

  let timeout = match timeout with 
    | Some f -> f
    | None   -> (fun () -> false) 
  in

  let rec loop = function Do step -> 
    if timeout () then raise Timeout ;
    match Lazy.force step with 
      | h :: t -> List.iter (fun x -> Queue.push x queue) t ; loop h
      | []     -> match try Some (Queue.pop queue) with Queue.Empty -> None with
	  | Some thread -> loop thread
	  | None        -> () 
  in

  loop (m ctx emit) ;
  match !r with None -> assert false | Some result -> result

let start ctx ms = 
  let m c emit = emit () ; Do (lazy (List.map (fun m -> m c (fun _ -> nop)) ms)) in
  eval ctx m 

let timeout duration = 
  let ends = duration +. Unix.gettimeofday () in
  fun () -> Unix.gettimeofday () > ends 
