(* © 2014 RunOrg *)

module I = SentMailLib.I
module Link = SentMailLib.Link

include SentMailLib.Commands
include SentMailLib.Queries

let run () = 
  SentMailLib.Common.ping_sender_service () 
