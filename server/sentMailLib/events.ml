(* © 2014 RunOrg *)

open Std

include type module

    (* A new wave is created. Includes a copy of all the data required to render
       the mail, because it will need to remain as-is just in case the original
       is edited afterwards. *)
  [ `GroupWaveCreated of <
      id : I.t ;
      pid : PId.t option ;
      mid : Mail.I.t ;
      gid : GId.t ;
      from : PId.t ;
      subject : Unturing.t ;
      text : Unturing.t option ;
      html : Unturing.t option ;
      custom : Json.t ;
      urls : String.Url.t list ; 
      self : String.Url.t option ; 
    >

    (* A batch of contacts is scheduled for receiving a copy, as part of a wave. 
       Contacts are numbered (with 'pos' being the position of the first contact
       in this batch). Note that contacts are scheduled even if they have already
       been sent this mail OR they do not exist. *)
  | `BatchScheduled of <
      id   : I.t ;
      mid  : Mail.I.t ; 
      pos  : int ;
      list : PId.t list ; 
    >

    (* The e-mail has actually been sent to the specified contact. *)
  | `Sent of <
      id      : I.t ;
      mid     : Mail.I.t ;
      pid     : PId.t ;
      from    : < name : string option ; email : string > ; 
      to_     : < name : string option ; email : string > ; 
      input   : Json.t ; 
      link    : Link.Root.t ; 
    >

    (* A link in the e-mail was clicked or followed. The event indicates whether
       the link was an auto-follow link or a clicked link. *)
  | `LinkFollowed of <
      id   : I.t ;
      mid  : Mail.I.t ;
      pid  : PId.t ;
      link : [ `Self | `Tracker | `Url of int ] ;
      auth : Token.I.t option ; 
      auto : bool ;
      ip   : IpAddress.t ; 
    >
      
    (* The sending subsystem could not compose and/or send the e-mail, and gave
       up permanently. *)
  | `SendingFailed of <
      mid  : Mail.I.t ;
      pid  : PId.t ;
      why  : [ `NoInfoAvailable 
	     | `NoSuchRecipient 
	     | `NoSuchSender    of PId.t 
	     | `SubjectError    of string * int * int 
	     | `TextError       of string * int * int 
	     | `HtmlError       of string * int * int 
	     | `Exception       of string 
	     ]	
    >

  ]
