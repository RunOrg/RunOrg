(* Ohm is © 2012 Victor Nicollet *)

type ( -'ctx, +'value ) t

type ('ctx,'value) value = ('ctx,'value) t
type 'ctx effect = ('ctx,unit) t
type 'ctx thread = 'ctx effect

(** {2 Monad usage} *)

val return  : 'value -> ('ctx,'value) t 
val bind    : ('a -> ('ctx,'b) t) -> ('ctx,'a) t -> ('ctx,'b) t
val map     : ('a -> 'b) -> ('ctx,'a) t -> ('ctx,'b) t
val unwrap  : ('ctx,('ctx,'a) t) t -> ('ctx,'a) t

(** {2 Context manipulation} *)

val context : ('ctx,'ctx) t
val with_context : 'ctx -> ('ctx,'a) t -> ('any,'a) t 
val edit_context : ('ca -> 'cb) -> ('cb,'any) t -> ('ca,'any) t

(** {2 Evaluation} *)

exception Timeout

val eval : ?timeout:(unit -> bool) -> 'ctx -> ('ctx,'a) t -> 'a 

val start : 'ctx -> 'ctx thread list -> unit

val timeout : float -> (unit -> bool) 

(** {2 Concurrency manipulation} *)

val yield  : ('ctx,'value) t -> ('ctx,'value) t 
val join   : ('ctx,'a) t -> ('ctx,'b) t -> ('a -> 'b -> ('ctx,'c) t) ->  ('ctx,'c) t
val fork   : 'ctx effect -> ('ctx,'a) t -> ('ctx,'a) t 

class ['ctx] joiner : object
  method wait : ('ctx, unit) t
  method start : ('ctx, unit) t -> ('ctx, unit) t 
end 

class mutex : object
  method lock : ('ctx, 'a) t -> ('ctx, 'a) t 
  method if_unlocked : ('ctx, 'a) t -> ('ctx, 'a) t 
end

(** {2 Utilities} *)

val memo : ('ctx,'a) t -> ('ctx,'a) t

val of_call  : ('a -> ('ctx,'b) t) -> 'a -> ('ctx,'b) t
val of_func  : (unit -> 'value) -> ('ctx,'value) t
val of_lazy  :    'value Lazy.t -> ('ctx,'value) t

val list_map     : ( 'it -> ('ctx,'value) t ) -> 'it list -> ('ctx,'value list) t 
val list_filter  : ( 'it -> ('ctx,'value option) t ) -> 'it list -> ('ctx,'value list) t
val list_collect : ( 'it -> ('ctx,'value list) t ) -> 'it list -> ('ctx,'value list) t
val list_find    : ( 'it -> ('ctx,'value option) t ) -> 'it list -> ('ctx,'value option) t
val list_fold    : ( 'it -> 'acc -> ('ctx,'acc) t ) -> 'acc -> 'it list -> ('ctx,'acc) t 
val list_mfold   : ( 'it -> ('ctx,'acc -> ('ctx,'acc) t) t) -> 'acc -> 'it list -> ('ctx,'acc) t
val list_iter    : ( 'it -> 'ctx effect ) -> 'it list -> 'ctx effect
val list_exists  : ( 'it -> ('ctx, bool) t ) -> 'it list -> ('ctx,bool) t

val opt_map      : ( 'a  -> ('ctx,'b) t ) -> 'a option -> ('ctx,'b option) t 
val opt_bind     : ( 'a  -> ('ctx,'b option) t ) -> 'a option -> ('ctx,'b option) t 

val loop         : ( ('ctx,'a) t -> ('ctx,'a) t ) -> ('ctx, 'a) t

val sleep        : float -> ('ctx, unit) t 
