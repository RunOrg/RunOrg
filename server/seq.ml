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

  (* Blocking version uses a semaphore to wait for values to 
     become available. *)

  let semaphore = new Run.semaphore in
  let blist = List.map (fun source -> ref false, source) list in 
  
  let rec wait () =
    let! n = next () in  
    match n with `End -> return None | `Next x -> return (Some x) | `Blocked -> 
      Run.fork 
	(fun exn -> return ())
	(List.M.iter (fun (blocked, source) -> 
	  if !blocked then return () else (
	    let () = blocked := true in
	    let! value = source.wait () in
	    let () = blocked := false in 
	    match value with 
	    | None -> return ()
	    | Some value -> let () = Queue.add value queue in 
			    semaphore # give 1)) blist)
	(let! () = semaphore # take in
	 wait ())
  in

  { finite = List.for_all is_finite list ; next ; wait }
    
let of_finite_cursor fetch cursor = 

  (* Both blocking and non-blocking versions use a semaphore. 
     But the non-blocking version checks the semaphore state first. *)

  let q = Queue.create () in
  let semaphore = new Run.semaphore in 
  let e = ref false in
  let cursor = ref cursor in  
  let runs = ref false in

  let run () = 
    if !runs then return () else  
      let () = runs := true in 
      let! list, c = fetch !cursor in 
      let () = 
	runs := false ;
	cursor := c ;
	e := c = None ;
	List.iter (fun x -> Queue.push x q) list ;
      in
      semaphore # give (List.length list)
  in

  let rec next () = 
    if !e then 
      return `End 
    else if semaphore # count <= 0 then
      Run.fork (fun exn -> return ()) (run ()) (return `Blocked)
    else
      let! () = semaphore # take in 
      return (`Next (Queue.take q))
  in

  let rec wait () = 
    if !e then 
      return None 
    else 
      let! () = if semaphore # count <= 0 then run () else return () in 
      let! () = semaphore # take in       
      return (Some (Queue.take q))
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
