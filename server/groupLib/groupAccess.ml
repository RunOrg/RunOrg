(* © 2014 RunOrg *)

include Access.Make(struct

  include type module
      [ `Admin    "admin"
      | `Moderate "moderate"
      | `List     "list"
      ]

  let all = 
    [ `Admin,     [`Moderate] ;
      `Moderate,  [`List] ;
      `List,      []
    ]

end)
