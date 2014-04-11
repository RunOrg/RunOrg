(* © 2014 RunOrg *)

include Access.Make(struct

  include type module
      [ `Admin "admin"
      | `View  "view"
      ]

  let all = 
    [ `Admin, [`View] ;
      `View,  []
    ]

end)
