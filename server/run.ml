(* © 2013 RunOrg *)

open BatResult

(* Types, both public and private 
   ============================== *)

type thr             = Do of thr list Lazy.t 

(* A thread is evaluated using: 
   - a context 
   - a successful return function (called on the result) 
   - a failed return function (called on the exception)

   The thread may call one of the two return functions directly, 
   and may return zero, one or more new threads to be added to the
   evaluation queue.    

   Such a function (usually either m or mFoo below) never raises
   exceptions, nor does the lazy evaluation of the returned [thr]  
   raise an exception. 

   Also, while the failed return function never
   raises exceptions either, the successful return function may 
   raise exceptions, and so should be defended against.
*)

type ('ctx,'value) t = 'ctx -> (exn -> thr) -> ('value -> thr) -> thr

type ('ctx,'value) value  = ('ctx,'value) t
type 'ctx          effect = ('ctx,unit) t
type 'ctx          thread = ('ctx,unit) t

(* Monad usage 
   =========== *)

let return x = fun ctx bad ok -> Do (lazy [try ok x with exn -> bad exn])   

let bind f m = fun ctx bad ok -> 
  m ctx bad (fun x -> 
    match catch f x with 
    | Ok  m   -> m ctx bad ok 
    | Bad exn -> bad exn) 

let map  f m = fun ctx bad ok ->
  m ctx bad (fun x -> try ok (f x) with exn -> bad exn)

let unwrap m = fun ctx bad ok -> 
  m ctx bad (fun m -> m ctx bad ok) 

(* Internal usage only *)
let (|>>) m f = map f m 

(* Context manipulation 
   ==================== *)

let context = fun ctx bad ok -> Do (lazy [try ok ctx with exn -> bad exn]) 

let with_context ctx m = fun _ bad ok -> m ctx bad ok

let edit_context f m = fun ctx bad ok -> 
  match catch f ctx with 
  | Ok  ctx -> m ctx bad ok
  | Bad exn -> bad exn

(* Concurrency manipulation 
   ======================== *)

let nop = Do (lazy [])

let yield m = fun ctx bad ok -> Do (lazy [nop ; m ctx bad ok]) 

let join a b f = fun ctx bad ok -> 

  let finish xa xb = match catch (f xa) xb with 
    | Bad exn -> bad exn 
    | Ok  m   -> m ctx bad ok 
  in

  let ra = ref None and rb = ref None in 
  let ok_a xa = match !rb with 
    | None    -> ra := Some xa ; nop
    | Some xb -> finish xa xb
  and ok_b xb = match !ra with
    | None    -> rb := Some xb ; nop
    | Some xa -> finish xa xb
  in

  Do (lazy [a ctx bad ok_a ; b ctx bad ok_b]) 

let fork a b = fun ctx bad ok -> 
  Do (lazy [b ctx bad ok ; a ctx (fun _ -> nop) (fun _ -> nop)])

class ['ctx] joiner = object (self) 

  val mutable count    = 0
  val mutable after    = None

  method wait : ('ctx,unit) t = fun _ bad ok -> 
    if count = 0 then 
      try ok () with exn -> bad exn 
    else 
      ( after <- Some (bad,ok) ; nop )
	
  method start (m : ('ctx, unit) t) = 
    count <- count + 1 ;
    let emit_if_zero () = 
      count <- count - 1 ;
      if count = 0 then match after with 
        | None -> nop
        | Some (bad,ok) -> ( after <- None ; try ok () with exn -> bad exn )
      else nop
    in
    fun ctx bad ok -> Do (lazy [ (try ok () with exn -> bad exn) ; m ctx bad emit_if_zero ]) 
      
end

class mutex = object (self)

  (* Functions in this queue will never throw. *)
  val waiting = Queue.create ()

  val mutable locked = false

  method lock : 'ctx 'a . ('ctx, 'a) t -> ('ctx, 'a) t = fun m ctx bad ok -> 

    let ok r = 
      if Queue.is_empty waiting then begin
	locked <- false ;
	ok r 
      end else begin
	let next = Queue.take waiting in
	Do (lazy [ next () ; (try ok r with exn -> bad exn) ])
      end
    in
      
    if locked then begin 
      Queue.add (fun () -> m ctx bad ok) waiting ; nop
    end else begin 
      locked <- true ; m ctx bad ok
    end

  method if_unlocked : 'ctx 'a . ('ctx, 'a) t -> ('ctx, 'a) t = fun m ->
    if locked then self # lock m else m 
    
end 

(* Utilities 
   ========= *)

let memo m = 
  let r = ref None in 
  fun c bad ok -> Do (lazy [(
    match !r with 
    | Some (c',v) when c' == c -> (try ok v with exn -> bad exn) 
    | _ -> m c bad (fun x -> r := Some (c,x) ; ok x) 
  )])

let of_lazy l = fun _ bad ok -> Do (lazy [try ok (Lazy.force l) with exn -> bad exn])
let of_func f = fun _ bad ok -> Do (lazy [try ok (f ()) with exn -> bad exn])

let of_call f a = fun ctx bad ok -> 
  match catch f a with 
  | Ok  m   -> m ctx bad ok
  | Bad exn -> bad exn

(* List functions 
   ============== *)

module ForList = struct

  let map f l = fun ctx bad ok -> 
    if l = [] then try ok [] with exn -> bad exn else 

      let failed = ref false in
      let bad exn = if !failed then nop else (failed := true ; bad exn) in 

      let list = List.map (fun x -> x, ref None) l in

      let num_unevaled = ref (List.length l) in
      let ok r y = 
	if !failed then nop else begin
	  if !r = None then decr num_unevaled ; 
	  r := Some y ;
	  if !num_unevaled > 0 then nop 
	  else ok (List.map 
		     (fun (x,r) -> match !r with Some y -> y | None -> assert false) 
		     list)
	end
      in

      Do (lazy (List.map begin fun (x,r) -> 
	match catch f x with 
	| Ok  m   -> m ctx bad (ok r)
	| Bad exn -> bad exn
      end list))
	
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
		       
  let iter f l = fun ctx bad ok -> 
    if l = [] then try ok () with exn -> bad exn else 

      let failed = ref false in
      let bad exn = if !failed then nop else (failed := true ; bad exn) in

      let r = ref (List.length l) in 
      let ok () = 
	if !failed then nop else ( decr r ; if !r = 0 then ok () else nop) 
      in

      Do (lazy (List.map begin fun x -> 
	match catch f x with 
	| Ok  m   -> m ctx bad ok
	| Bad exn -> bad exn
      end l))
	
  let exists pred l = 
    find (fun x -> pred x |>> (fun px -> if px then Some () else None)) l
    |>> BatOption.is_some

end

module ForOption = struct

  let map f = function 
    | None   -> (fun ctx bad ok -> try ok None with exn -> bad exn)
    | Some x -> (fun ctx bad ok -> match catch f x with 
      | Bad exn -> bad exn
      | Ok  m   -> m ctx bad (fun y -> ok (Some y)))
      
  let bind f = function
    | None   -> (fun ctx bad ok -> try ok None with exn -> bad exn)
    | Some x -> (fun ctx bad ok -> match catch f x with 
      | Bad exn -> bad exn
      | Ok  m   -> m ctx bad ok)

end

let loop f = 
  let rec loop () = f (yield (of_call loop ())) in loop () 

let sleep t = 
  let ends = Unix.gettimeofday () +. t in
  loop (fun continue -> if Unix.gettimeofday () < ends then continue else return ())

(* Evaluation 
   ========== *)

exception Timeout 

let eval ?timeout ctx m = 
  let queue   = Queue.create () in 
  let r       = ref None in 
  let ok  x   = r := Some x ; nop in 
  let bad exn = raise exn in

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

  loop (m ctx bad ok) ;
  match !r with None -> assert false | Some result -> result

let start ctx ms = 

  let retry m = fun ctx _ ok -> 
    let rec bad exn = Do (lazy [nop ; m ctx bad ok]) in
    m ctx bad ok 
  in
  
  eval ctx (ForList.iter retry ms) 

let timeout duration = 
  let ends = duration +. Unix.gettimeofday () in
  fun () -> Unix.gettimeofday () > ends 
