open Ohm

module T = struct
  type & t = 
  | UserLoggedIn of < session_id : I.t ; user_id : User.I.t ; remember_me : bool >
end

module F = struct
  include T
  include Fmt.Extend(T)
end

include Cqrs.Stream(struct
  include F
  let name = "session"
end)


    
