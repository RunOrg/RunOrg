open BatOption
open Run
open Std

type ('ctx,'x) t = {
  finite : bool ;
  next : unit -> ('ctx, [`Blocked | `End | `Next of 'x]) Run.t ;
  wait : unit -> ('ctx, 'x option) Run.t ;	 
}

let is_finite t = t.finite
let next t = t.next ()
let wait t = t.wait ()

let to_list ?min n t = 

  let min = default n min in

  let rec take i acc = 
    if i = n then return acc
    else
      let! n = next t in 
      match n with 
      | `End -> return acc
      | `Next x -> take (i+1) (x :: acc)
      | `Blocked -> if i >= min then return acc else
	  let! n = wait t in 
	  match n with 
	  | Some x -> take (i+1) (x :: acc) 
	  | None -> return acc
  in
  
  let! reverse_list = take 0 [] in
  return (List.rev reverse_list)

let map f t = { 
  finite = t.finite ; 
  next = (fun () -> 
    let! n = next t in 
    return (match n with 
    | `Blocked -> `Blocked
    | `End -> `End
    | `Next x -> `Next (f x))) ; 
  wait = (fun () -> 
    let! n = wait t in 
    return (BatOption.map f n)) 
}
  
let mmap f t = { 
  finite = t.finite ; 
  next = (fun () -> 
    let! n = next t in match n with 
      | `Blocked -> return `Blocked
      | `End -> return `End
      | `Next x -> let! y = f x in return (`Next y)) ;
  wait = (fun () ->
    let! n = wait t in 
    Option.M.map f n) 
}
      
let filter f t = 

  let rec new_next () = 
    let! n = next t in match n with 
      | `Blocked -> return `Blocked
      | `End -> return `End
      | `Next x -> match f x with 
	| Some y -> return (`Next y) 
	| None -> new_next ()
  in	    

  let rec new_wait () = 
    let! n = wait t in match n with 
      | None -> return None
      | Some x -> match f x with 
	| Some y -> return (Some y)
	| None -> new_wait () 
  in

  { finite = t.finite ; next = new_next ; wait = new_wait }

let mfilter f t = 

  let rec new_next () = 
    let! n = next t in match n with 
      | `Blocked -> return `Blocked
      | `End -> return `End
      | `Next x -> let! yopt = f x in 
		   match yopt with 
		   | Some y -> return (`Next y) 
		   | None -> new_next ()
  in	    

  let rec new_wait () = 
    let! n = wait t in match n with 
      | None -> return None
      | Some x -> let! yopt = f x in 
		  match yopt with 
		  | Some y -> return (Some y)
		  | None -> new_wait () 
  in

  { finite = t.finite ; next = new_next ; wait = new_wait }

let miter ~parallel f t = 

  let start, split = 
    if parallel then
      let joiner = new joiner in 
      (fun work   -> let! () = joiner # start (work ()) in joiner # wait), 
      (fun work x -> let! () = joiner # start (f x) in work ())
    else 
      (fun work -> work ()), 
      (fun work x -> let! () = f x in work ())
  in
  
  let rec work () = 
    let! n = wait t in match n with 
      | None -> return () 
      | Some x -> split work x
  in
  
  start work  

let iter ~parallel f t =
  miter ~parallel (fun x -> of_lazy (lazy (f x))) t

let of_list list =

  let queue   = ref list in 
  let wait () = 
    return (match !queue with 
    | [] -> None
    | h :: t -> queue := t ; Some h)
  in
  let next () = 
    Run.map (function
    | None   -> `End
    | Some x -> `Next x)  (wait ())
  in

  { finite = true ; next ; wait }

(* TODO: join [] and join [x] special cases. *)

let join list = 

  (* Non-blocking version shares a queue with the blocking version, 
     because the blocking version starts up threads that load more than
     one value (possibly one for each source). *)

  let queue = Queue.create () in

  let rec next = function 
    | [] -> return `Blocked
    | h :: t -> let! r = h.next () in 
		match r with 
		| `End | `Blocked -> next t
		| `Next x -> return (`Next x) 
  in

  let next () = 
    if Queue.is_empty queue then next list else 
      return (`Next (Queue.pop queue))
  in

  let mutex = new Run.mutex in

  let search () =
    let! n = next () in  
    match n with `End -> return None | `Next x -> return (Some x) | `Blocked -> 

      let not_empty = ref (List.length list) in
      let semaphore = new Run.semaphore in 

      (* Forks a parallel search for any value, then waits on a semaphore. The forked
	 threads trigger the semaphore when a value is found OR when all lists have
	 turned up empty. *)
      Run.fork 
	(fun exn -> return ())

	(List.M.iter (fun source -> 
	  let! value = source.wait () in
	  match value with 
	  | None -> decr not_empty ; if !not_empty = 0 then semaphore # give 1 else return ()
	  | Some value -> let () = Queue.add value queue in 
			  semaphore # give 1) list)

	(let! () = semaphore # take in
	 return (if Queue.is_empty queue then None else Some (Queue.pop queue)))
  in

  let wait () = mutex # lock (Run.of_call search ()) in

  { finite = List.for_all is_finite list ; next ; wait }
    
let of_finite_cursor fetch cursor = 
  
  (* An internal 'query_if_emptyn' function fills the queue with elements, 
     using a mutex to have only one instance running at a time, and sets 
     'empty' to true when no more elements are available.  *)
  
  let queue  = Queue.create () in
  let mutex  = new Run.mutex in
  let empty  = ref false in
  let cursor = ref cursor in  

  let query_if_empty () = 
    mutex # lock begin 
      if not (Queue.is_empty queue) then return () else 
	let! list, c = if !empty then return ([],None) else fetch !cursor in 
	return (
	  cursor := c ;
	  empty  := c = None ;
	  List.iter (fun x -> Queue.push x queue) list ;
	)
    end
  in

  let rec next () = 
    if mutex # locked then return `Blocked else
      if not (Queue.is_empty queue) then return (`Next (Queue.take queue)) else
	if !empty then return `End else
	  Run.fork (fun exn -> return ()) (query_if_empty ()) (return `Blocked)
  in

  let rec wait () = 
    let! () = query_if_empty () in
    return (if Queue.is_empty queue then None else Some (Queue.take queue))
  in

  { finite = true ; next ; wait }

let of_infinite_cursor ?wait fetch cursor = 

  let rec defwait n = if n < 5 then defwait (n + 1) /. 2. else 10000.0 in
  let wait = Option.default defwait wait in

  let q = Queue.create () in
  let semaphore = new Run.semaphore in 
  let cursor = ref cursor in  
  let runs = ref false in

  (* Extracts data from the source. Keeps going until data is available. *)
  let rec extract retries = 
    let! list, c = fetch !cursor in 
    let () = 
      cursor := Some c ;
      List.iter (fun x -> Queue.push x q) list ;
    in
    if list = [] then 
      let! () = Run.sleep (wait retries) in
      extract (retries + 1) 
    else       
      return (fun () -> semaphore # give (List.length list))
  in

  (* Makes sure there is a single "extract" process running. *)
  let run () = 
    if !runs then return () else        
      let  () = runs := true in 
      let! finish = extract 0 in 
      let  () = runs := false in      
      finish () 
  in

  let rec next () = 
    if semaphore # count <= 0 then
      Run.fork (fun exn -> return ()) (run ()) (return `Blocked)
    else
      let! () = semaphore # take in 
      return (`Next (Queue.take q))
  in

  let rec wait () = 
    let! () = if semaphore # count <= 0 then run () else return () in 
    let! () = semaphore # take in       
    return (Some (Queue.take q))
  in
  
  { finite = false ; next ; wait }
