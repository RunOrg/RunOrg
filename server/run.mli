(* © 2013 RunOrg *)

(** Lightweight cooperative threads, with context. *)

(** A lightweight thread that computes a value of type ['value] in a context
    of type ['ctx']. This is semantically similar to ['ctx -> 'value], except
    that the computation of [('ctx,'value) t] may be broken down into smaller
    substeps to allow concurrency.

    A thread may be executed more than once: it will perform the same
    operation again. 
*)
type ( -'ctx, +'value ) t

(** A lightweight thread that performs a side-effect, then returns. 
    Use this type, rather than ['ctx thread], to indicate your intent of 
    having a short-lived operation. *)
type 'ctx effect = ('ctx,unit) t

(** A lightweight thread that runs forever, performing side-effects. 
    Use this type, rather than ['ctx effect], to indicate your intent of
    having a long-lived operation. *)
type 'ctx thread = 'ctx effect

(** {2 Monad usage} *)

(** Wraps an already-computed value in a lightweight thread. 

    {[
    let! value = return 12 in
    assert(value = 12)
    ]}

    Likely to be the most used function in this module. 
*)
val return  : 'value -> ('ctx,'value) t 

(** Start a new thread from the result of another. 

    In practice, use [let!] rather than [bind] for clarity: by definition, 
    [let! a = b in c] is equivalent to [bind (fun a -> b) c]. 
*)
val bind    : ('a -> ('ctx,'b) t) -> ('ctx,'a) t -> ('ctx,'b) t

(** Apply a function to the result of a thread. 

    [map f t] is equivalent to [bind (f |- return) t]
*)
val map     : ('a -> 'b) -> ('ctx,'a) t -> ('ctx,'b) t

(** A thread-that-returns-a-thread-that-returns-X can be seen as
    a thread-that-returns-X. *)
val unwrap  : ('ctx,('ctx,'a) t) t -> ('ctx,'a) t

(** {2 Context manipulation} *)

(** A thread that returns the context it was executed in. Typical usage: 

    {[ let! ctx = context in ]}
*)
val context : ('ctx,'ctx) t

(** Run a thread in the specified context. This returns a thread
    which can be executed in any context (since that context will 
    be replaced with the specified context). 

    {[ 
with_context 10 (
  let! ctx = context in 
  assert(ctx = 10))
    ]}
*)
val with_context : 'ctx -> ('ctx,'a) t -> ('any,'a) t 

(** A helper function for using {!context} and {!with_context} in
    succession. 

    {[
with_context 10 (
  edit_context ((+) 5) (
    let! ctx = context in 
    assert(ctx = 15)))
*)
val edit_context : ('ca -> 'cb) -> ('cb,'any) t -> ('ca,'any) t

(** {2 Evaluation} *)

(** Evaluates a thread in a context. Runs until all threads 
    spawned by the original thread have completed.

    If an exception is raised by a thread, all threads immediately 
    stop and the exception escapes [eval]. Note that forked threads
    may fail without causing the evaluation to fail.

    {[ assert( 10 = eval 5 (let! n = context in return (n * 2)) ) ]}
*)
val eval : 'ctx -> ('ctx,'a) t -> 'a 

(** Start several long-running operations in parallel. 

    If an exception is raised by a thread, and [exn_handler] returns 
    true, then that thread is killed and all threads which were 
    dependent on it are aborted, then the root thread is restarted. 
    
    If [exn_handler] returns false, the exception bubbles up. 
    By default, [exn_handler] always returns true. 

    For instance, after calling [start ctx [a;b]], if the evaluation 
    of thread [a] (or one of the sub-threads on which it is dependent)
    causes an exception, then [a] will be re-started from scratch. 
*)
val start : ?exn_handler:(exn -> bool) -> 'ctx -> 'ctx thread list -> unit

(** {2 Concurrency manipulation} *)

(** [yield t] gives {b all} other threads on the system a chance to run, then 
    returns. *)
val yield  : ('ctx,'a) t -> ('ctx,'a) t 

(** [join a b f] will run [a] and [b] in parallel, yielding results [a'] and [b'], 
    then return [f a' b']. *)
val join   : ('ctx,'a) t -> ('ctx,'b) t -> ('a -> 'b -> ('ctx,'c) t) ->  ('ctx,'c) t

(** [fork x a] will run [x] at some point in the future, and returns [a]. *)
val fork   : (exn -> 'ctx effect) -> 'ctx effect -> ('ctx,'a) t -> ('ctx,'a) t 

(** A thread joiner is used to wait for an arbitrary number of threads to finish. 

    The code below waits until both [frobnicate 1] and [frobnicate 2] have 
    finished running, then returns. 

    {[
    let frobincate : int -> 'ctx effect = (* Some long-running operation *) in
    let joiner = new joiner in
    fork (joiner # start (frobnicate 1))
      (fork (joiner # start (frobnicate 2))
        (joiner # wait))    
    ]}
*)
class ['ctx] joiner : object

  (** Waits until all threads started with [start] have finished, then returns. *)
  method wait : ('ctx, unit) t

  (** The passed thread will block [wait] until it is finished. *)
  method start : ('ctx, unit) t -> ('ctx, unit) t 

end 

(** A mutually exclusive lock. *)
class mutex : object

  (** Blocks until the mutex is unlocked, then locks the mutex, executes
      the thread, and unlocks the mutex when it is finished. 
    
      The locking thread should {b never} lock the mutex again: doing so 
      will cause a deadlock. *)
  method lock : ('ctx, 'a) t -> ('ctx, 'a) t 

  (** If the mutex is currently unlocked, runs the thread without locking.
      If the mutex is locked, performs exactly as [lock]. *)
  method if_unlocked : ('ctx, 'a) t -> ('ctx, 'a) t 

end

(** A counting semaphore.*)
class ['ctx] semaphore : object

  (** The number of gives minus the number of takes *)
  method count : int 

  (** If there are threads waiting on the semaphore, unlocks the oldest one 
      and runs it. The argument is the number of [give]s to be given
      (that is, the number of threads to be unlocked). *)
  method give : int -> ('ctx, unit) t 

  (** If [give] was called more than [take], executes the passed thread. 
      Otherwise, the passed thread is blocked until [give] is called. *)
  method take : ('ctx, unit) t 

end 

(** Call a function in a background thread, return a task that waits
    for the result of that function. *)

val background : ('a -> 'b) -> 'a -> ('ctx, 'b) t 

(** {2 Utilities} *)

(** If [memo t] is executed several times in the same context, then it may 
    cache the result of [t] instead of evaluating [t] every single time. 
    There is, however, no guarantee about the specific number of times 
    [t] may be called (except that it will be called at least once in each
    different context).
*)
val memo : ('ctx,'a) t -> ('ctx,'a) t

(** [of_call f a] is equivalent to [bind f (return a)] *) 
val of_call  : ('a -> ('ctx,'b) t) -> 'a -> ('ctx,'b) t

(** [of_func f] is equivalent to [of_call f ()] *)
val of_func  : (unit -> 'value) -> ('ctx,'value) t

(** [of_lazy l] forces [l] every time it is evaluated. *)
val of_lazy  :    'value Lazy.t -> ('ctx,'value) t

(** [of_channel c] attempts to read a value from channel [c] every time it
    is evaluated. *)
val of_channel : 'value Event.channel -> ('ctx,'value) t

(** [on_failure f m] attempts to run [m], and calls [f exn] if an exception
    occurred while running [m]. *)
val on_failure : (exn -> ('ctx,'a) t) -> ('ctx,'a) t -> ('ctx,'a) t

(** [finally f m] calls [f ()] when [m] has finished running (whether 
    successfully or because of an exception). Any threads forked during
    the execution of [m] may still be running. *)
val finally : (unit -> unit) -> ('ctx,'a) t -> ('ctx,'a) t

(** [loop (fun continue -> ...)] runs its body and returns the
    result. The body may return [continue] to have the loop 
    run its body again. 

    {[
    let n = ref 10 in
    loop (fun continue ->
      if !n = 0 then return () else (decr n ; continue))
    ]}

    Note that [continue] internally uses [yield]: every other thread
    will get a chance to run in-between iterations of the loop.
*)
val loop : ( ('ctx,'a) t -> ('ctx,'a) t ) -> ('ctx, 'a) t

(** List operations. These are also available as part of {!Std.List.M}. 
    
    Unless otherwise noted, they are the equivalent of their [List] module 
    counterparts, but with the functions returning threads instead of 
    values. 

    Unless otherwise noted, they are {b not} sequential. For example, 
    [ForList.map f [a;b]] may excute [f a] before or after (or during) 
    the evaluation of [f b]. 
*)
module ForList : sig
    
  val map        : ( 'it -> ('ctx,'value) t ) -> 'it list -> ('ctx,'value list) t 
  val filter_map : ( 'it -> ('ctx,'value option) t ) -> 'it list -> ('ctx,'value list) t
  val filter     : ( 'it -> ('ctx,bool) t ) -> 'it list -> ('ctx,'it list) t
  val iter       : ( 'it -> 'ctx effect ) -> 'it list -> 'ctx effect

  (** Sequential *)
  val iter_seq   : ( 'it -> 'ctx effect ) -> 'it list -> 'ctx effect 

  (** Sequential by definition. *)
  val fold_left  : ( 'acc -> 'it -> ('ctx,'acc) t ) -> 'acc -> 'it list -> ('ctx,'acc) t 

  (** Sequential: [find f l] only calls [f] on elements before the one that returned [true]. *)
  val exists     : ( 'it -> ('ctx, bool) t ) -> 'it list -> ('ctx,bool) t

  (** Sequential: [find f l] only calls [f] on elements before the returned element. *)
  val find       : ( 'it -> ('ctx,'value option) t ) -> 'it list -> ('ctx,'value option) t

  (** [collect f l] is equivalent to [Run.map List.flatten (map f l)]. *) 
  val collect    : ( 'it -> ('ctx,'value list) t ) -> 'it list -> ('ctx,'value list) t

  (** [mfold f acc l] is equivalent to [bind (fold_left (fun a f -> f a) acc) (map f l)]. This 
      means the [map] part is parallel and the [fold] part is sequential. *)
  val mfold      : ( 'it -> ('ctx,'acc -> ('ctx,'acc) t) t) -> 'acc -> 'it list -> ('ctx,'acc) t

end

(** Option operations. These are also available as part of {!Std.Option.M} 

    They are the equivalent of their [Option] module counterparts. *)

module ForOption : sig

  val map       : ( 'a  -> ('ctx,'b) t ) -> 'a option -> ('ctx,'b option) t 
  val bind      : ( 'a  -> ('ctx,'b option) t ) -> 'a option -> ('ctx,'b option) t 

end

(** [sleep 1000.0] is a thread that returns after 1 second. *)
val sleep        : float -> ('ctx, unit) t 
