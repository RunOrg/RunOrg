(* © 2014 RunOrg *)

include Access.Make(struct

  include type module
      [ `Admin    "admin"
      | `Moderate "moderate"
      | `Write    "write"
      | `Read     "read"
      | `View     "view"
      ]

  let all = 
    [ `Admin,     [`Moderate] ;
      `Moderate,  [`Write] ;
      `Write,     [`Read] ; 
      `Read,      [`View] ;
      `View,      [] ;
    ]

end)
