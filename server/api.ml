(* © 2013 RunOrg *)

open Std

include ApiLib

let config = Httpd.(Configuration.Httpd.({ 
  port ; 
  key_path ; 
  certificate_path ; 
  key_password ;
  max_header_size ;
  max_body_size ;
  max_duration ; 
})) 

let run () = 
  Httpd.start config (fun req -> 

    let ctx = new O.ctx in

    let ctx = match req # at with None -> ctx | Some clock -> ctx # with_after clock in 

    Run.with_context ctx begin 

      let! auth_error = 
	match req # as_ with None -> return None | Some cid -> 
	  match req # token with 
	  | None -> return (Some (!! "Token needed to act as %S." (CId.to_string cid)))
	  | Some token -> let! ok = Token.can_be token cid in
			  if ok then return None else
			    return (Some (!! "Token %S does not allow acting as %S." 
					     (Token.I.to_string token) (CId.to_string cid)))
      in

      match auth_error with
      | None -> Endpoint.dispatch req
      | Some msg -> return (Httpd.json ~status:`Unauthorized (Json.Object ["error", Json.String msg ]))
	
    end)
