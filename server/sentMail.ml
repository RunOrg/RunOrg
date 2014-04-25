(* © 2014 RunOrg *)

module I = SentMailLib.I
module Link = SentMailLib.Link
module Status = SentMailLib.Status

type failure = SentMailLib.Compose.failure

include SentMailLib.Commands
include SentMailLib.Queries

let run () = 
  SentMailLib.Common.ping_sender_service () 

