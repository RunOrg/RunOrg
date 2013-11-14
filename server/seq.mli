(** An enumerator, returns new values while executed in a certain context. 
    May be VERY long. *)

(** An sequence containing objects of type ['x], evaluated in context ['ctx]. 
    Built from a 'next' function. *)
type ('ctx,'a) t 

(** Is this a finite sequence. *)
val is_finite : ('ctx, 'a) t -> bool
  
(** Turn a sequence into a list containing at most N elements. 
    If min is provided, stops adding elements to the list if the
    enumeration is blocked and there are at least min elements in the 
    list already. 
    
    This is a {b very} dangerous function to use on infinite sequences,
    unless you set [min] to zero. *)
val to_list : ?min:int -> int -> ('ctx, 'a) t -> ('ctx, 'a list) Run.t

(** Read the next value from an enumerator. This is a low-level reading
    function. *)
val next : ('ctx, 'a) t -> ('ctx, [`Blocked | `End | `Next of 'a]) Run.t

(** Waits until the next value is available. 
    
    This is a {b very} dangerous function to use on infinite sequences,
    because it can block forever. *)
val wait : ('ctx, 'a) t -> ('ctx, 'a option) Run.t

(** Apply a map function to all items. *)
val map : ('a -> 'b) -> ('ctx, 'a) t -> ('ctx, 'b) t

(** Apply an in-context map function to all items. *)
val mmap : ('a -> ('ctx, 'b) Run.t) -> ('ctx, 'a) t -> ('ctx, 'b) t
    
(** Apply a filter-map function to all items. *)
val filter : ('a -> 'b option) -> ('ctx, 'a) t -> ('ctx, 'b) t

(** Apply an in-context filter-map function to an enumerator. *)
val mfilter : ('a -> ('ctx, 'b option) Run.t) -> ('ctx, 'a) t -> ('ctx, 'b) t

(** Apply a function to every item, either in sequence or in parallel. *)
val iter : parallel:bool -> ('a -> unit) -> ('ctx, 'a) t -> 'ctx Run.effect

(** Apply an in-context function to every item, either in sequence or
    in parallel. *)
val miter : parallel:bool -> ('a -> 'ctx Run.effect) -> ('ctx, 'a) t -> 'ctx Run.effect

(** Create an enumerator from a list. *)
val of_list : 'a list -> ('ctx, 'a) t

(** Joins several enumerators together. Will always read from the 
    first non-blocked sub-enumerator. *)
val join : ('ctx, 'x) t list -> ('ctx, 'x) t

(** Create an enumerator from a finite cursor. The cursor returns a list of 
    items, plus an offset. When the cursor returns no offset, the end of
    the enumeration has been reached. 

    Marked as blocked when the elements returned by one query have been
    used up (blocking is benign : querying will take longer than usual
    but execution time is still bounded).
*)
val of_finite_cursor : 
  ('cursor option -> ('ctx, 'a list * 'cursor option) Run.t) -> 
   'cursor option -> ('ctx, 'a) t

(** Create an enumerator from an infinite cursor. Behaves like a finite 
    cursor, except that it never ends. 

    Marked as blocked when there are no more elements currently available
    (the query returns an empty list). Blocking is critical : querying can
    take unbounded time.
*)
val of_infinite_cursor : 
  ('cursor option -> ('ctx, 'a list * 'cursor) Run.t) ->
   'cursor option -> ('ctx, 'a) t
