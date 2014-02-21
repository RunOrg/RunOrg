(* © 2014 RunOrg *)

open Std

(* Curl library is probably not re-entrant. Just in case, use a mutex to prevent
   several background threads from running Curl requests at the same time.  *)
let curl_lock = Mutex.create () 

module ApiResponse = type module <
  status   : [ `okay ] ;
  email    : string ; 
  audience : string ;
  expires  : float ;
  issuer   : string ; 
>

let validate ~audience assertion = 

  let data = Json.serialize (Json.Object [
    "audience", Json.String audience ;
    "assertion", Json.String assertion
  ]) in

  (* Delegate verifier request to background thread. *)
  let! response = Run.background begin fun data -> 

    let buffer = Buffer.create 1763 in

    let () = 
      Mutex.lock curl_lock ;
      try 
	let curl = Curl.init () in
	Curl.set_url curl "https://verifier.login.persona.org/verify" ;
	Curl.set_writefunction curl (fun x -> Buffer.add_string buffer x ; String.length x) ;
	Curl.set_post curl true ;
	Curl.set_httpheader curl [ "Content-type: application/json" ] ;
	Curl.set_postfields curl data ;
	Curl.set_postfieldsize curl (String.length data) ;
	Curl.perform curl ;
	Curl.global_cleanup () ;
	Mutex.unlock curl_lock ;
      with exn ->
	Mutex.unlock curl_lock ;
	raise exn
    in

    Buffer.contents buffer 

  end data in 

  return (Option.map (#email) (ApiResponse.of_json_string_safe response))
  
