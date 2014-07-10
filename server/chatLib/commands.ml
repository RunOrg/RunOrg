(* © 2014 RunOrg *)

open Std

let create ?subject people groups = 
  let  id = I.gen () in 
  let! clock = Store.append [ Events.chatCreated ~id ~people ~groups ~subject ] in
  return (id, clock) 

let createPublic subject =
  let  id = I.gen () in 
  let! clock = Store.append [ Events.publicChatCreated ~id ~subject ] in
  return (id, clock) 

let delete id = 
  Store.append [ Events.chatDeleted ~id ]

let createPost id author body = 
  let  post = PostI.gen () in 
  let! clock = Store.append [ Events.postCreated ~id ~post ~author ~body ] in
  return (post, clock) 

let deletePost id post = 
  Store.append [ Events.postDeleted ~id ~post ]
