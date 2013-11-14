open BatOption
open Run

type ('ctx,'x) t = {
  finite : bool ;
  next : unit -> ('ctx, [`Blocked | `End | `Next of 'x]) Run.t
}

let is_finite t = t.finite
let next t = t.next ()

let to_list ?min n t = 

  let min = default n min in

  let rec take i acc = 
    if i = n then return acc
    else
      let! n = next t in 
      match n with 
      | `End -> return acc
      | `Next x -> take (i+1) (x :: acc)
      | `Blocked -> if i < min then Run.yield (take i acc) else return acc 
  in
  
  let! reverse_list = take 0 [] in
  return (List.rev reverse_list)
    
let rec wait_next t = 

  let! n = next t in 
  match n with 
  | `End -> return None
  | `Next x -> return (Some x)
  | `Blocked -> Run.yield (Run.of_call wait_next t) 
    
let map f t = 
  { finite = t.finite ; next = (fun () -> 
      let! n = next t in 
      return (match n with 
      | `Blocked -> `Blocked
      | `End -> `End
      | `Next x -> `Next (f x))) }
    
let mmap f t = 
  { finite = t.finite ; next = (fun () -> 
    let! n = next t in match n with 
      | `Blocked -> return `Blocked
      | `End -> return `End
      | `Next x -> let! y = f x in return (`Next y)) }
      
let filter f t = 

  let rec new_next () = 
    let! n = next t in match n with 
      | `Blocked -> return `Blocked
      | `End -> return `End
      | `Next x -> match f x with 
	| Some y -> return (`Next y) 
	| None -> new_next ()
  in	    
  
  { finite = t.finite ; next = new_next }

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
  
  { finite = t.finite ; next = new_next }

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
    let! n = next t in match n with 
      | `Blocked -> yield (work ())
      | `End -> return () 
      | `Next x -> split work x
  in
  
  start work  

let iter ~parallel f t =
  miter ~parallel (fun x -> of_lazy (lazy (f x))) t

let of_list list =

  let queue   = ref list in 
  let next () = 
    return (match !queue with 
    | [] -> `End
    | h :: t -> queue := t ; `Next h)
  in

  { finite = true ; next }

let join list = 

  let rec next = function 
    | [] -> return `Blocked
    | h :: t -> let! r = h.next () in 
		match r with 
		| `End | `Blocked -> next t
		| `Next x -> return (`Next x) 
  in
  
  { finite = List.for_all is_finite list ; next = (fun () -> next list) }
    
let of_finite_cursor fetch cursor = 
  let q = Queue.create () in
  let e = ref false in
  let cursor = ref cursor in  
  let runs = ref false in
  let rec next () = 
    if !e then 
      return `End 
    else if Queue.is_empty q then
      
      if !runs then return `Blocked else begin
	runs := true ;
	Run.fork begin 
	  let! list, c = fetch !cursor in 
	  return (
	    runs := false ; 
	    cursor := c ; 
	    e := c = None ; 
	    List.iter (fun x -> Queue.push x q) list ;
	  )
	end (return `Blocked) 
      end

    else
      return (`Next (Queue.take q))
  in
  
  { finite = true ; next }

let of_infinite_cursor fetch cursor = 
  let q = Queue.create () in
  let cursor = ref cursor in  
  let rec next () = 
    if Queue.is_empty q then
      let! list, c = fetch !cursor in 
      begin 
	cursor := Some c ; 
	List.iter (fun x -> Queue.push x q) list ;
	if Queue.is_empty q then 
	  let! () = Run.sleep 2000. in 
	  return `Blocked 
	else
	  return (`Next (Queue.take q))
      end
    else
      return (`Next (Queue.take q))
  in
  
  { finite = false ; next }
