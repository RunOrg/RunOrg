(* © 2014 RunOrg *)

open Std

let projection = Cqrs.Projection.make "mail" O.config

(* Mail information by identifier. 
   =============================== *)

module Info = type module <
  from     : CId.t ;
  subject  : String.Label.t ;
  text     : string option ;
  html     : String.Rich.t option ; 
  audience : MailAccess.Audience.t ; 
  custom   : Json.t ;
  urls     : String.Url.t list ; 
>

let info = 

  let infoV, info = Cqrs.MapView.make projection "info" 1 
    (module I : Fmt.FMT with type t = I.t)
    (module Info : Fmt.FMT with type t = Info.t) in

  let () = Store.track infoV begin function

    | `Created ev -> 
      
      Cqrs.MapView.update info (ev # id) 
	(function 
	| None   -> `Put (Info.make 
			    ~from:(ev # from) 
			    ~subject:(match ev # subject with `Raw s -> s) 
			    ~text:(match ev # text with `None -> None | `Raw s -> Some s)
			    ~html:(match ev # html with `None -> None | `Raw s -> Some s) 
			    ~custom:(ev # custom) ~urls:(ev # urls) ~audience:(ev # audience))
	| Some _ -> `Keep) 

  end in

  info

(* Finding mail by access level
   ============================ *)

let byAccess = 
  
  let byAccessV, byAccess = MailAccess.Map.make projection "byAccess" 0 
    ~only:[`Admin;`View] (module I : Fmt.FMT with type t = I.t) in

  let () = Store.track byAccessV begin function

    | `Created ev -> 

      MailAccess.Map.update byAccess (ev # id) (ev # audience) 

  end in

  byAccess

