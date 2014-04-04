(* © 2014 RunOrg *)

include Access.Make(struct

  include type module
      [ `Admin "admin"
      | `Fill  "fill"
      ]

  let all = 
    [ `Admin, [`Fill] ;
      `Fill,  []
    ]

end)
