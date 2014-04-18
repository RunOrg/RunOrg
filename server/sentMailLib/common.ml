(* © 2014 RunOrg *)

open Std

let sender_service = ref None 

let set_sender_service service = 
  sender_service := Some service

let ping_sender_service () = 
  match !sender_service with None -> return () | Some service -> Run.ping service
