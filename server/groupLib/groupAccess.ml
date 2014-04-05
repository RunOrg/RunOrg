(* © 2014 RunOrg *)

include Access.Make(struct

  include type module
      [ `Admin    "admin"
      | `Moderate "moderate"
      | `List     "list"
      | `View     "view"
      ]

  let all = 
    [ `Admin,     [`Moderate] ;
      `Moderate,  [`List] ;
      `List,      [`View] ;
      `View,      [] ;
    ]

end)
