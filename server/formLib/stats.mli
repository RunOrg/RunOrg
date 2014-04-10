(* © 2014 RunOrg *)

open Std

module FieldStat : Fmt.FMT with type t = 
  [ `Text of <
      missing : int ;
      filled  : int ;
      words   : int ;
    >
  | `Time of <
      missing : int ;
      filled  : int ;
      first   : Time.t option ;
      last    : Time.t option ;
    >
  | `Json of <
      missing   : int ;
      filled    : int ;
    >
  | `Single of <
      missing : int ;
      filled  : int ;
      items   : int array ;
    >
  | `Multi of <
      missing : int ;
      filled  : int ;
      items   : int array ;
    >
  | `Contact of <
      missing : int ;
      filled : int ;
      contacts : int ;
      top100 : (CId.t * int) list ;
    >
  ]

module Summary : Fmt.FMT with type t = 
  ( Field.I.t, FieldStat.t ) Map.t

val compute : (I.t, Summary.t) Cqrs.HardStuffCache.t 
