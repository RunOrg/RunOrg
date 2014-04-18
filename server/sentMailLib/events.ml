(* © 2014 RunOrg *)

include type module

    (* A new wave is created. Includes a copy of all the data required to render
       the mail, because it will need to remain as-is just in case the original
       is edited afterwards. *)
  [ `GroupWaveCreated of <
      id : I.t ;
      cid : CId.t option ;
      mid : Mail.I.t ;
      gid : GId.t ;
      from : CId.t ;
      subject : Unturing.t ;
      text : Unturing.t option ;
      html : Unturing.t option ;
      custom : Json.t ;
      urls : string list ; 
      self : string option ; 
    >

    (* A batch of contacts is scheduled for receiving a copy, as part of a wave. 
       Contacts are numbered (with 'pos' being the position of the first contact
       in this batch). Note that contacts are scheduled even if they have already
       been sent this mail OR they do not exist. *)
  | `BatchScheduled of <
      id   : I.t ;
      mid  : Mail.I.t ; 
      pos  : int ;
      list : CId.t list ; 
    >

    (* The e-mail has actually been sent to the specified contact. *)
  | `Sent of <
      id      : I.t ;
      mid     : Mail.I.t ;
      cid     : CId.t ;
      contact : Json.t ; 
    >

    (* A link in the e-mail was clicked or followed. The event indicates whether
       the link was an auto-follow link or a clicked link. *)
  | `LinkFollowed of <
      id   : I.t ;
      mid  : Mail.I.t ;
      cid  : CId.t ;
      link : [ `Self | `Tracker | `Url of int ] ;
      auto : bool ;
      ip   : IpAddress.t ; 
    >
      
    (* The sending subsystem could not compose and/or send the e-mail, and gave
       up permanently. *)
  | `SendingFailed of <
      id   : I.t ;
      mid  : Mail.I.t ;
      cid  : CId.t ;
      why  : [ `NoSuchContact ]
    >

  ]
