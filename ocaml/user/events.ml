open Ohm

module T = struct
  type & t = 
    | CreatedBySystem of < id : I.t ; email : string >
    | NameUpdated of < id : I.t ; firstname : string ; lastname : string >
    | PasswordUpdated of < id : I.t ; hash : string >
    | Deleted of < id : I.t >
end

include Ohm.Cqrs.Stream(struct
  include T
  include Fmt.Extend(T) 
  let name = "user"
end) 

include T
